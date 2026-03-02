import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/data/settings_repository.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/screens/castle_screen.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';
import 'package:iron_and_stone/ui/widgets/company_marker.dart';
import 'package:iron_and_stone/ui/widgets/map_node_widget.dart';
import 'package:iron_and_stone/ui/widgets/split_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const Duration _tickInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _checkFirstRunHint();
    _startGameLoop();
  }

  void _startGameLoop() {
    _gameLoopTimer = Timer.periodic(_tickInterval, (_) {
      if (mounted) {
        ref.read(matchNotifierProvider.notifier).tick();
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _gameLoopTimer?.cancel();
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
      final selectedCo = companyState.companies
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
            boundaryMargin: const EdgeInsets.all(80),
            minScale: 0.5,
            maxScale: 3.0,
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
                  // Company markers — only show player companies and companies at
                  // nodes the player can see (all castles + road nodes are always visible).
                  // AI companies are visible (fog-of-war is out of scope for MVP).
                  ...companies.map((co) {
                    final (cx, cy) = _nodeCanvasPos(co.currentNode);
                    final isSelected = co.id == selectedId;

                    return Positioned(
                      left: cx - 18,
                      top: cy - 18,
                      child: CompanyMarker(
                        key: ValueKey('company_marker_${co.id}'),
                        company: co,
                        x: cx,
                        y: cy,
                        isSelected: isSelected,
                        onTap: () => _onCompanyTap(context, co, companyState),
                        onLongPress: co.ownership == Ownership.player
                            ? () => _onCompanyLongPress(context, co)
                            : null,
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
      backgroundColor: AppTheme.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SplitSlider(
          key: ValueKey('split_slider_${co.id}'),
          company: co,
          onConfirm: (splitMap) {
            Navigator.of(ctx).pop();
            ref
                .read(companyNotifierProvider.notifier)
                .splitCompany(co.id, splitMap);
          },
        ),
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

    // No selection: if tapping a castle, open the castle sheet.
    if (node is CastleNode) {
      _showCastleSheet(context, node, matchState);
    }
  }

  /// Bottom sheet shown when a castle node is tapped with no company selected.
  ///
  /// Shows a quick-deploy button AND a "Manage" button that navigates to
  /// [CastleScreen] for full garrison management.
  void _showCastleSheet(
    BuildContext context,
    CastleNode castleNode,
    MatchState matchState,
  ) {
    final castle = matchState.castles.firstWhere((c) => c.id == castleNode.id);
    final garrisonWarriors = castle.garrison[UnitRole.warrior] ?? 0;
    final deployCount = garrisonWarriors >= 5 ? 5 : garrisonWarriors;
    final isPlayerCastle = castle.ownership == Ownership.player;

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
              Text(
                'Garrison: ${castle.garrison.values.fold(0, (s, v) => s + v)} soldiers',
                style: const TextStyle(color: AppTheme.stone, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (isPlayerCastle && deployCount > 0) ...[
                ElevatedButton.icon(
                  key: const ValueKey('deploy_company_button'),
                  icon: const Icon(Icons.shield),
                  label: Text('Quick Deploy $deployCount Warriors'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(companyNotifierProvider.notifier).deployCompany(
                      castleId: castle.id,
                      castleNode: castleNode,
                      composition: {UnitRole.warrior: deployCount},
                      map: matchState.match.map,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bloodRed,
                    foregroundColor: AppTheme.parchment,
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (isPlayerCastle) ...[
                const Text(
                  'No warriors available to deploy.',
                  style: TextStyle(color: AppTheme.stone),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
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

