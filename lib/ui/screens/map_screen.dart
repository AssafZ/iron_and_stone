import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      body: matchAsync.when(
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

    return InteractiveViewer(
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

              return Positioned(
                left: cx - 24,
                top: cy - 24,
                child: MapNodeWidget(
                  key: ValueKey(nodeKey),
                  node: node,
                  onTap: () => _onNodeTap(context, node, matchState, companyState),
                ),
              );
            }),
            // Company markers
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

    if (selectedId != null && selectedId != co.id) {
      // Check if the currently selected Company is on the same node — offer merge.
      final selectedCo = state.companies.firstWhere(
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
      // Second tap: assign destination.
      ref.read(companyNotifierProvider.notifier).setDestination(
            companyId: selectedId,
            destination: node,
            map: matchState.match.map,
          );
      return;
    }

    // No selection: if tapping player castle, navigate to CastleScreen.
    if (node is CastleNode && node.ownership == Ownership.player) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CastleScreen(castleId: node.id),
        ),
      );
    }
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

// ---------------------------------------------------------------------------
// Deploy bottom sheet helper (used by the screen)
// ---------------------------------------------------------------------------

/// Shows the deploy confirmation bottom sheet for a player castle.
///
/// Provides a simple "Deploy 5 Warriors" button for the MVP skeleton.
Future<void> showDeploySheet(
  BuildContext context,
  WidgetRef ref,
  MatchState matchState,
  CastleNode castleNode,
) async {
  final castle = matchState.castles.firstWhere((c) => c.id == castleNode.id);
  final garrisonWarriors = castle.garrison[UnitRole.warrior] ?? 0;
  final deployCount = garrisonWarriors >= 5 ? 5 : garrisonWarriors;

  if (deployCount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No warriors available to deploy.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Deploy Company from ${castle.id}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ironDark,
                ),
              ),
              const SizedBox(height: 16),
              Text('Warriors available: $garrisonWarriors'),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey('deploy_company_button'),
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
                child: Text('Deploy $deployCount Warriors'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
