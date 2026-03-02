import 'package:flutter/material.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

/// Renders a single [MapNode] on the map canvas.
///
/// Uses [RepaintBoundary] to prevent repaints of unchanged nodes.
/// Tapping dispatches [onTap] upward; no game logic lives here.
///
/// [liveOwnership] overrides [CastleNode.ownership] to reflect real-time
/// castle captures. [isReachable] highlights the node when a company is
/// selected and this node is a valid movement destination.
class MapNodeWidget extends StatelessWidget {
  final MapNode node;
  final bool isSelected;

  /// Live ownership for CastleNodes — reflects captures that occurred during the match.
  final Ownership? liveOwnership;

  /// True when a company is selected and this node is reachable.
  final bool isReachable;

  final VoidCallback? onTap;

  const MapNodeWidget({
    super.key,
    required this.node,
    this.isSelected = false,
    this.liveOwnership,
    this.isReachable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: _buildNode(context),
      ),
    );
  }

  Widget _buildNode(BuildContext context) {
    if (node is CastleNode) {
      return _buildCastleNode(node as CastleNode);
    }
    return _buildJunctionNode();
  }

  Widget _buildCastleNode(CastleNode castle) {
    // Use liveOwnership (battle results) over the static fixture ownership.
    final ownership = liveOwnership ?? castle.ownership;
    final color = switch (ownership) {
      Ownership.player => AppTheme.bloodRed,
      Ownership.ai => AppTheme.midnightBlue,
      Ownership.neutral => AppTheme.stone,
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(6),
        border: isReachable
            ? Border.all(color: AppTheme.gold, width: 3)
            : isSelected
                ? Border.all(color: AppTheme.gold, width: 3)
                : Border.all(color: AppTheme.ironDark, width: 2),
        boxShadow: [
          if (isReachable)
            const BoxShadow(
              color: AppTheme.gold,
              blurRadius: 8,
              spreadRadius: 1,
            )
          else
            const BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
        ],
      ),
      child: const Icon(Icons.castle, color: Colors.white, size: 24),
    );
  }

  Widget _buildJunctionNode() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isReachable
            ? AppTheme.gold
            : isSelected
                ? AppTheme.gold
                : AppTheme.stone,
        shape: BoxShape.circle,
        border: Border.all(
          color: isReachable ? AppTheme.ironDark : AppTheme.ironDark,
          width: isReachable ? 2 : 1,
        ),
        boxShadow: isReachable
            ? [
                const BoxShadow(
                  color: AppTheme.gold,
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
