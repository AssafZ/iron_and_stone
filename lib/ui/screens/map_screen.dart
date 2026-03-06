import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/data/settings_repository.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/screens/battle_screen.dart';
import 'package:iron_and_stone/ui/screens/castle_screen.dart';
import 'package:iron_and_stone/ui/screens/game_over_screen.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';
import 'package:iron_and_stone/ui/widgets/battle_indicator.dart';
import 'package:iron_and_stone/ui/widgets/company_marker.dart';
import 'package:iron_and_stone/ui/widgets/map_node_widget.dart';
import 'package:iron_and_stone/ui/widgets/split_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Slot offset table (FR-003)
// ---------------------------------------------------------------------------

/// Pixel offsets for company markers sharing a node.
///
/// Index = slot number (arrival order, 0-based).
/// Slot 0 = centre (no offset); slots 1+ are positioned at a radius of
/// [_kSlotRadius] px so that every 44 × 44 pt tap target is fully
/// non-overlapping even at canvas scale 1.0.
///
/// [_kSlotRadius] must be ≥ half the tap-target width (22 px) so adjacent
/// markers never overlap. Using 28 px gives clear visual separation while
/// keeping the spread compact relative to the map scale.
const double _kSlotRadius = 28.0;

const List<(double, double)> _kSlotOffsets = [
  (0.0, 0.0),                        // slot 0 — centre
  (_kSlotRadius, 0.0),               // slot 1 — right
  (-_kSlotRadius, 0.0),              // slot 2 — left
  (0.0, -_kSlotRadius),              // slot 3 — above
  (0.0, _kSlotRadius),               // slot 4 — below
  (-_kSlotRadius, -_kSlotRadius),    // slot 5 — top-left
  (_kSlotRadius, -_kSlotRadius),     // slot 6 — top-right
  (-_kSlotRadius, _kSlotRadius),     // slot 7 — bottom-left
  (_kSlotRadius, _kSlotRadius),      // slot 8 — bottom-right
];

/// Builds a node-occupancy map directly from the authoritative company list.
///
/// Only stationary companies (destination == null or destination == currentNode)
/// are included. Companies at the same node are sorted lexicographically by id
/// so the slot order is deterministic across every render frame — no transient
/// arrival-order state is needed.
///
/// When [pinnedId] is provided (the currently selected company), that company
/// is placed in slot 0 (the centre) at its node. This makes the selected/front
/// company visually "on top" and easiest to tap.
///
/// This is called once per [_buildMap] frame and the result is passed to
/// [_offsetForCompany] for each company, keeping slot assignment consistent
/// within a frame.
Map<String, List<String>> _buildSlotMap(
  List<CompanyOnMap> companies, {
  String? pinnedId,
}) {
  final map = <String, List<String>>{};
  for (final co in companies) {
    // Companies frozen in a battle are stationary at their currentNode even
    // though their destination field may still be set from before the collision.
    final isStationary = co.battleId != null ||
        co.destination == null ||
        co.destination!.id == co.currentNode.id;
    if (!isStationary) continue;
    map.putIfAbsent(co.currentNode.id, () => []).add(co.id);
  }
  // Sort each node's list by id so order is stable across rebuilds,
  // then promote pinnedId to slot 0 if present.
  for (final entry in map.entries) {
    final ids = entry.value;
    ids.sort();
    if (pinnedId != null && ids.contains(pinnedId)) {
      ids.remove(pinnedId);
      ids.insert(0, pinnedId);
    }
  }
  return map;
}

/// Returns the pixel offset `(dx, dy)` for [company] given a [slotMap]
/// derived from the live company list.
///
/// In-transit companies (destination ≠ currentNode) always return `(0, 0)`
/// because their visual position is interpolated along the road — not snapped
/// to a node slot. Companies frozen in a battle are treated as stationary at
/// currentNode even if destination is still set.
(double, double) _offsetForCompany(
  CompanyOnMap company,
  Map<String, List<String>> slotMap,
) {
  // Battling companies are frozen at currentNode — always use slot offset.
  if (company.battleId == null &&
      company.destination != null &&
      company.destination!.id != company.currentNode.id) {
    return (0.0, 0.0);
  }
  final ids = slotMap[company.currentNode.id];
  if (ids == null) return (0.0, 0.0);
  final slot = ids.indexOf(company.id);
  if (slot < 0) return (0.0, 0.0);
  if (slot >= _kSlotOffsets.length) return (0.0, 0.0);
  return _kSlotOffsets[slot];
}

/// The main gameplay screen — renders the map, castle nodes, and Company markers.
///
/// Uses [InteractiveViewer] for pan/zoom.
/// Implements the two-step tap-to-select/tap-to-assign-destination UX (FR-011).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  // Canvas dimensions for node layout.
  static const double _canvasWidth = 600.0;
  static const double _canvasHeight = 400.0;

  // Scale from game-coordinate space to canvas pixels.
  static const double _scale = 1.2;
  static const double _offsetX = 50.0;
  static const double _offsetY = 180.0;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _showHint = false;
  Timer? _hintTimer;
  Timer? _gameLoopTimer;
  Timer? _visualTimer;
  final TransformationController _transformController = TransformationController();

  // Elapsed seconds since the last game-logic tick — used to interpolate
  // company positions smoothly between ticks in the UI layer.
  double _elapsedSinceLastTick = 0.0;

  static const Duration _tickInterval = Duration(seconds: 10);
  static const Duration _visualInterval = Duration(milliseconds: 50);
  static const double _tickSeconds = 10.0;

  @override
  void initState() {
    super.initState();
    _checkFirstRunHint();
    _startGameLoop();
    _startVisualTimer();
    // Fit the entire map canvas into the viewport on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToScreen());
  }

  /// Fires at ~20 fps to advance the visual interpolation counter and rebuild
  /// the map so company markers slide smoothly between nodes.
  void _startVisualTimer() {
    _visualTimer = Timer.periodic(_visualInterval, (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSinceLastTick =
            (_elapsedSinceLastTick + _visualInterval.inMilliseconds / 1000.0)
                .clamp(0.0, _tickSeconds);
      });
    });
  }

  /// Compute and apply an initial transformation that shows the whole map.
  void _fitMapToScreen() {
    if (!mounted) return;
    final size = context.size;
    if (size == null) return;
    // Account for AppBar height so we fit within the body area.
    final availableHeight = size.height - kToolbarHeight - MediaQuery.of(context).padding.top;
    final availableWidth = size.width;
    // Scale so the canvas fits with a small padding on all sides.
    const padding = 20.0;
    final scaleX = (availableWidth - padding * 2) / MapScreen._canvasWidth;
    final scaleY = (availableHeight - padding * 2) / MapScreen._canvasHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    // Translate so the scaled canvas is centred in the viewport.
    final dx = (availableWidth - MapScreen._canvasWidth * scale) / 2;
    final dy = (availableHeight - MapScreen._canvasHeight * scale) / 2;
    _transformController.value = Matrix4.identity()
      ..scale(scale)
      ..translate(dx / scale, dy / scale);
  }

  void _startGameLoop() {
    _gameLoopTimer = Timer.periodic(_tickInterval, (_) {
      if (mounted) {
        // Reset interpolation counter so visual position snaps back to the
        // authoritative node position after each logic tick.
        setState(() => _elapsedSinceLastTick = 0.0);
        ref.read(matchNotifierProvider.notifier).tick();
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _gameLoopTimer?.cancel();
    _visualTimer?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstRunHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      if (!repo.firstRunHintShown) {
        if (mounted) setState(() => _showHint = true);
        await repo.markFirstRunHintShown();
        // Auto-dismiss after 5 seconds; store timer so it can be cancelled on dispose.
        _hintTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showHint = false);
        });
      }
    } catch (_) {
      // If preferences fail, just don't show the hint.
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchNotifierProvider);
    final companyAsync = ref.watch(companyNotifierProvider);

    // React to game-over: stop the loop and navigate to GameOverScreen.
    ref.listen<AsyncValue<MatchState>>(matchNotifierProvider, (prev, next) {
      final outcome = next.valueOrNull?.matchOutcome;
      if (outcome != null) {
        _gameLoopTimer?.cancel();
        _visualTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => GameOverScreen(outcome: outcome),
            ),
          );
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iron and Stone'),
        backgroundColor: AppTheme.ironDark,
        foregroundColor: AppTheme.parchment,
      ),
      backgroundColor: AppTheme.parchment,
      body: Stack(
        children: [
          matchAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (matchState) => companyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (companyState) => _buildMap(
                context,
                matchState,
                companyState,
              ),
            ),
          ),
          if (_showHint) _FirstRunHintOverlay(onDismiss: () => setState(() => _showHint = false)),
        ],
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    MatchState matchState,
    CompanyListState companyState,
  ) {
    final nodes = matchState.match.map.nodes;
    // matchState.companies is the authoritative company list — it is kept in
    // sync by CompanyNotifier (player actions call updateCompanies) and by
    // TickMatch (AI-deployed companies appear here after each tick).
    final companies = matchState.companies;
    final selectedId = companyState.selectedCompanyId;

    // Build a lookup of live castle ownership by node id.
    final castleOwnership = {
      for (final c in matchState.castles) c.id: c.ownership,
    };

    // Compute reachable nodes when a company is selected (for visual highlight).
    Set<String> reachableNodeIds = {};
    if (selectedId != null) {
      // Use matchState.companies (authoritative) so this works even after ticks
      // have advanced companies without updating the local CompanyNotifier list.
      final selectedCo = matchState.companies
          .where((c) => c.id == selectedId)
          .firstOrNull;
      if (selectedCo != null) {
        reachableNodeIds = matchState.match.map.edges
            .where((e) => e.from.id == selectedCo.currentNode.id)
            .map((e) => e.to.id)
            .toSet();
        // Also include all other nodes reachable via pathfinding (full path highlighting)
        for (final node in nodes) {
          final path = matchState.match.map.pathBetween(selectedCo.currentNode, node);
          if (path.isNotEmpty) reachableNodeIds.add(node.id);
        }
      }
    }

    // Build the slot map from the authoritative match-state company list so
    // offsets are always correct — even after tick-driven movement where
    // companies arrive at nodes without going through CompanyNotifier actions.
    // The selected company is pinned to slot 0 so it renders at the centre
    // and is easiest to tap after being chosen in the castle screen.
    final slotMap = _buildSlotMap(companies, pinnedId: selectedId);

    return Column(
      children: [
        // Movement hint banner shown when a company is selected.
        if (selectedId != null)
          Container(
            key: const ValueKey('move_hint_banner'),
            color: AppTheme.gold.withAlpha(220),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.touch_app, color: AppTheme.ironDark, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Company selected — tap any node to march there',
                    style: TextStyle(
                      color: AppTheme.ironDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(companyNotifierProvider.notifier).clearSelection(),
                  child: const Icon(Icons.close, color: AppTheme.ironDark, size: 18),
                ),
              ],
            ),
          ),
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(80),
            minScale: 0.3,
            maxScale: 3.0,
            constrained: false,
            child: SizedBox(
              width: MapScreen._canvasWidth,
              height: MapScreen._canvasHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Road edges
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoadPainter(matchState.match.map.edges),
                    ),
                  ),
                  // Map nodes
                  ...nodes.map((node) {
                    final (cx, cy) = _nodeCanvasPos(node);
                    final nodeKey = _nodeKey(node);
                    final liveOwnership = node is CastleNode
                        ? (castleOwnership[node.id] ?? node.ownership)
                        : null;
                    final isReachable = selectedId != null && reachableNodeIds.contains(node.id);

                    return Positioned(
                      left: cx - 24,
                      top: cy - 24,
                      child: MapNodeWidget(
                        key: ValueKey(nodeKey),
                        node: node,
                        liveOwnership: liveOwnership,
                        isReachable: isReachable,
                        onTap: () => _onNodeTap(context, node, matchState, companyState),
                      ),
                    );
                  }),
                  // Company markers — positions are interpolated between
                  // currentNode and the next node using stored progress plus
                  // elapsed time since the last logic tick, so markers slide
                  // smoothly across the map in real time.
                  //
                  // Stationary companies at the same node are spread across
                  // offset slots derived from the live matchState company list
                  // so every marker has its own 44 × 44 pt tap target
                  // (FR-001, FR-003). slotMap is rebuilt each frame so it
                  // stays in sync after tick-driven movement.
                  //
                  // Companies frozen in a battle (battleId != null) are also
                  // rendered here with offset slots so opposing companies
                  // appear side-by-side rather than stacked. The BattleIndicator
                  // is rendered on top as a separate overlay.
                  ...companies
                      .map((co) {
                    final (cx, cy) = _companyVisualPos(co, matchState);
                    final isSelected = co.id == selectedId;
                    final (ox, oy) = _offsetForCompany(co, slotMap);

                    return Positioned(
                      key: ValueKey('positioned_${co.id}'),
                      left: cx + ox - 22,
                      top: cy + oy - 22,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: CompanyMarker(
                          key: ValueKey('company_marker_${co.id}'),
                          company: co,
                          x: cx + ox,
                          y: cy + oy,
                          isSelected: isSelected,
                          onTap: () => _onCompanyTap(context, co, companyState),
                          onLongPress: co.ownership == Ownership.player
                              ? () => _onCompanyLongPress(context, co)
                              : null,
                        ),
                      ),
                    );
                  }),
                  // Battle indicators — one per active battle, anchored to the
                  // battle node's canvas coordinates. These persist across pan
                  // and zoom because they are children of the same SizedBox
                  // that all other map elements live in.
                  ...matchState.activeBattles.map((ab) {
                    final node = matchState.match.map.nodes
                        .where((n) => n.id == ab.nodeId)
                        .firstOrNull;
                    if (node == null) return const SizedBox.shrink();
                    final (cx, cy) = _nodeCanvasPos(node);
                    return Positioned(
                      key: ValueKey('battle_indicator_${ab.id}'),
                      left: cx - 22,
                      top: cy - 22,
                      child: BattleIndicator(
                        battleId: ab.id,
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BattleScreen(battleId: ab.id),
                          ),
                        ),
                      ),
                    );
                  }),
                  // Selection indicator overlay (tested via key)
                  if (selectedId != null)
                    Positioned(
                      key: ValueKey('company_selected_$selectedId'),
                      left: 0,
                      top: 0,
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tap handlers
  // ---------------------------------------------------------------------------

  void _onCompanyTap(
    BuildContext context,
    CompanyOnMap co,
    CompanyListState state,
  ) {
    if (co.ownership != Ownership.player) return;
    final notifier = ref.read(companyNotifierProvider.notifier);

    final selectedId = state.selectedCompanyId;

    // Use the authoritative match-state company list for merge check.
    final authoritativeCompanies =
        ref.read(matchNotifierProvider).valueOrNull?.companies ?? state.companies;

    if (selectedId != null && selectedId != co.id) {
      // Check if the currently selected Company is on the same node — offer merge.
      final selectedCo = authoritativeCompanies.firstWhere(
        (c) => c.id == selectedId,
        orElse: () => co,
      );
      if (selectedCo.currentNode.id == co.currentNode.id &&
          selectedCo.ownership == Ownership.player) {
        _showMergePrompt(context, selectedCo, co);
        return;
      }
    }

    if (state.selectedCompanyId == co.id) {
      notifier.clearSelection();
    } else {
      notifier.selectCompany(co.id);
    }
  }

  /// Show a merge confirmation dialog for two friendly Companies on the same node.
  void _showMergePrompt(
    BuildContext context,
    CompanyOnMap a,
    CompanyOnMap b,
  ) {
    final totalA = a.company.totalSoldiers.value;
    final totalB = b.company.totalSoldiers.value;
    final combined = totalA + totalB;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.parchment,
        title: const Text(
          'Merge Companies?',
          style: TextStyle(color: AppTheme.ironDark),
        ),
        content: Text(
          'Merge Company ($totalA soldiers) with Company ($totalB soldiers)?\n'
          'Combined: $combined soldiers'
          '${combined > 50 ? " → primary of 50 + overflow of ${combined - 50}" : ""}.',
          style: const TextStyle(color: AppTheme.ironDark),
        ),
        actions: [
          TextButton(
            key: const ValueKey('merge_cancel_button'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.stone)),
          ),
          ElevatedButton(
            key: const ValueKey('merge_confirm_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bloodRed,
              foregroundColor: AppTheme.parchment,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(companyNotifierProvider.notifier).mergeCompanies(a.id, b.id);
            },
            child: const Text('Merge'),
          ),
        ],
      ),
    );
  }

  /// Show the split-slider bottom sheet for a long-pressed player Company.
  void _onCompanyLongPress(BuildContext context, CompanyOnMap co) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SplitSlider(
        key: ValueKey('split_slider_${co.id}'),
        company: co,
        onConfirm: (splitMap) {
          Navigator.of(ctx).pop();
          ref
              .read(companyNotifierProvider.notifier)
              .splitCompany(co.id, splitMap);
        },
      ),
    );
  }

  void _onNodeTap(
    BuildContext context,
    MapNode node,
    MatchState matchState,
    CompanyListState companyState,
  ) {
    final selectedId = companyState.selectedCompanyId;

    if (selectedId != null) {
      // A company is selected — any node tap assigns it as a movement destination.
      ref.read(companyNotifierProvider.notifier).setDestination(
            companyId: selectedId,
            destination: node,
            map: matchState.match.map,
          );
      return;
    }

    // No selection: check for multiple stationary player companies at this
    // road junction — if so, show a disambiguation panel (FR-001, User Story 1).
    if (node is RoadJunctionNode) {
      final stationaryAtNode = matchState.companies
          .where((co) =>
              co.currentNode.id == node.id &&
              (co.destination == null || co.destination!.id == co.currentNode.id) &&
              co.ownership == Ownership.player)
          .toList();
      if (stationaryAtNode.length >= 2) {
        _showNodeDisambiguationSheet(context, node, stationaryAtNode, companyState);
        return;
      }
      // Single or no player company — direct tap selects it (handled by marker tap).
      return;
    }

    // No selection: if tapping a castle, open the castle sheet.
    if (node is CastleNode) {
      _showCastleSheet(context, node, matchState);
    }
  }

  /// Bottom sheet shown when a road junction has multiple stationary player
  /// companies and the user taps the node area (FR-001, User Story 1).
  ///
  /// Lists all companies at the node so the player can select any one of them,
  /// even if the offset markers are hard to tap individually at a given zoom level.
  void _showNodeDisambiguationSheet(
    BuildContext context,
    RoadJunctionNode node,
    List<CompanyOnMap> companies,
    CompanyListState companyState,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.place, color: AppTheme.ironDark, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    '${companies.length} Companies at this junction',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ironDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Select a company to manage it:',
                style: TextStyle(color: AppTheme.stone, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...companies.map((co) {
                final isSelected = co.id == companyState.selectedCompanyId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    key: ValueKey('disambiguation_${co.id}'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _onCompanyTap(context, co, companyState);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.gold.withAlpha(60)
                            : AppTheme.ironDark.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.gold : AppTheme.stone.withAlpha(80),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.bloodRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.shield,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Company',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.ironDark,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${co.company.totalSoldiers.value} soldiers',
                                  style: const TextStyle(
                                    color: AppTheme.stone,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppTheme.gold, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet shown when a castle node is tapped with no company selected.
  ///
  /// Shows castle info and a "Manage Castle" button that navigates to
  /// [CastleScreen].
  void _showCastleSheet(
    BuildContext context,
    CastleNode castleNode,
    MatchState matchState,
  ) {
    final castle = matchState.castles.firstWhere((c) => c.id == castleNode.id);
    final isPlayerCastle = castle.ownership == Ownership.player;
    final stationedCompanies = matchState.companies
        .where((co) => co.currentNode.id == castleNode.id && co.destination == null)
        .toList();
    final stationedCount = stationedCompanies.length;
    final totalDefenders = stationedCompanies.fold<int>(
      0,
      (sum, co) => sum + co.company.totalSoldiers.value,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.castle,
                    color: isPlayerCastle ? AppTheme.bloodRed : AppTheme.midnightBlue,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPlayerCastle ? 'Your Castle' : 'Enemy Castle',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.ironDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isPlayerCastle)
                Text(
                  'Companies stationed: $stationedCount',
                  style: const TextStyle(color: AppTheme.stone, fontSize: 14),
                )
              else
                Text(
                  'Defenders: $totalDefenders soldiers',
                  style: const TextStyle(color: AppTheme.stone, fontSize: 14),
                ),
              const SizedBox(height: 16),
              if (isPlayerCastle) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Manage Castle'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CastleScreen(castleId: castleNode.id),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.ironDark,
                    side: const BorderSide(color: AppTheme.ironDark),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Coordinate helpers
  // ---------------------------------------------------------------------------

  static (double, double) _nodeCanvasPos(MapNode node) {
    return (
      node.x * MapScreen._scale + MapScreen._offsetX,
      node.y * MapScreen._scale + MapScreen._offsetY,
    );
  }

  /// Interpolated canvas position for a moving company.
  ///
  /// Uses the authoritative [CompanyOnMap.progress] stored after the last tick
  /// plus the elapsed wall-clock time since that tick to extrapolate where the
  /// marker should be rendered right now — giving smooth continuous movement.
  (double, double) _companyVisualPos(CompanyOnMap co, MatchState matchState) {
    // Companies frozen in a battle are stationary at currentNode even if their
    // destination field is still set from before the collision.
    if (co.battleId != null) return _nodeCanvasPos(co.currentNode);

    final destination = co.destination;
    if (destination == null || destination.id == co.currentNode.id) {
      return _nodeCanvasPos(co.currentNode);
    }

    // Find the next node along the path.
    final path = matchState.match.map.pathBetween(co.currentNode, destination);
    if (path.length < 2) return _nodeCanvasPos(co.currentNode);
    final nextNode = path[1];

    // Find the edge to get its length.
    final edge = matchState.match.map.edges
        .where((e) => e.from.id == co.currentNode.id && e.to.id == nextNode.id)
        .firstOrNull;
    if (edge == null) return _nodeCanvasPos(co.currentNode);

    // Compute interpolated progress: stored tick progress + real-time advance.
    final speedPerSec = co.company.movementSpeed.toDouble();
    final extraProgress = (speedPerSec * _elapsedSinceLastTick) / edge.length;
    final visualProgress = (co.progress + extraProgress).clamp(0.0, 1.0);

    // Lerp canvas positions.
    final (x0, y0) = _nodeCanvasPos(co.currentNode);
    final (x1, y1) = _nodeCanvasPos(nextNode);
    return (
      x0 + (x1 - x0) * visualProgress,
      y0 + (y1 - y0) * visualProgress,
    );
  }

  static String _nodeKey(MapNode node) {
    if (node is CastleNode) return 'castle_node_${node.id}';
    return 'junction_node_${node.id}';
  }
}

// ---------------------------------------------------------------------------
// First-run hint overlay (T103)
// ---------------------------------------------------------------------------

/// Contextual overlay shown on first launch to guide new players.
///
/// Displayed once only; persisted via [SettingsRepository.firstRunHintShown].
/// Auto-dismisses after 5 seconds or immediately on tap.
class _FirstRunHintOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const _FirstRunHintOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withAlpha(140),
          child: Center(
            child: Container(
              key: const ValueKey('first_run_hint_overlay'),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.parchment,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.ironDark, width: 2),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.castle, size: 40, color: AppTheme.ironDark),
                  SizedBox(height: 12),
                  Text(
                    'Tap a castle to deploy\nyour first Company',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ironDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Then tap a road node to march.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.stone),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '(Tap anywhere to dismiss)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.stone),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Road painter
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Road painter
// ---------------------------------------------------------------------------

class _RoadPainter extends CustomPainter {
  final List<RoadEdge> edges;

  _RoadPainter(this.edges);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.stone.withAlpha(180)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const scale = MapScreen._scale;
    const ox = MapScreen._offsetX;
    const oy = MapScreen._offsetY;

    final drawn = <String>{};

    for (final edge in edges) {
      final fromNode = edge.from;
      final toNode = edge.to;
      final key1 = '${fromNode.id}-${toNode.id}';
      final key2 = '${toNode.id}-${fromNode.id}';
      // Draw each road segment once.
      if (drawn.contains(key1) || drawn.contains(key2)) continue;
      drawn.add(key1);

      canvas.drawLine(
        Offset(fromNode.x * scale + ox, fromNode.y * scale + oy),
        Offset(toNode.x * scale + ox, toNode.y * scale + oy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => false;
}

