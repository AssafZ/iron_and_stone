import 'package:flutter/material.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

/// Renders a single [MapNode] on the map canvas.
///
/// Uses [RepaintBoundary] to prevent repaints of unchanged nodes.
/// Tapping dispatches [onTap] upward; no game logic lives here.
class MapNodeWidget extends StatelessWidget {
  final MapNode node;
  final bool isSelected;
  final VoidCallback? onTap;

  const MapNodeWidget({
    super.key,
    required this.node,
    this.isSelected = false,
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
    final color = switch (castle.ownership) {
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
        border: isSelected
            ? Border.all(color: AppTheme.gold, width: 3)
            : Border.all(color: AppTheme.ironDark, width: 2),
        boxShadow: [
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
        color: isSelected ? AppTheme.gold : AppTheme.stone,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.ironDark, width: 1),
      ),
    );
  }
}
