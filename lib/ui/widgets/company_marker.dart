import 'package:flutter/material.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

/// Displays a Company marker at a given position on the map canvas.
///
/// Uses [AnimatedPositioned] for smooth position updates and [RepaintBoundary]
/// to prevent unnecessary repaints of sibling widgets.
///
/// Tapping the marker calls [onTap] (selection intent — no game logic here).
/// Long-pressing calls [onLongPress] (opens the split-slider sheet).
class CompanyMarker extends StatelessWidget {
  final CompanyOnMap company;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Canvas-space coordinates of the company's current position.
  final double x;
  final double y;

  const CompanyMarker({
    super.key,
    required this.company,
    required this.x,
    required this.y,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Center(child: _buildMarker()),
        ),
      ),
    );
  }

  /// Returns `true` when the company is actively moving toward a different node.
  bool get _isInTransit =>
      company.destination != null &&
      company.destination!.id != company.currentNode.id;

  Widget _buildMarker() {
    final marker = _buildVisualMarker();
    // FR-008: in-transit companies render at reduced opacity so the player can
    // distinguish moving markers from stationary ones at a glance.
    if (_isInTransit) {
      return Opacity(opacity: 0.65, child: marker);
    }
    return marker;
  }

  Widget _buildVisualMarker() {
    final ownerColor = company.ownership == Ownership.player
        ? AppTheme.bloodRed
        : AppTheme.midnightBlue;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ownerColor,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: AppTheme.gold, width: 3)
                : Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(1, 2),
              ),
            ],
          ),
          child: const Icon(Icons.shield, color: Colors.white, size: 18),
        ),
        // Unit count badge
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.gold,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              '${company.company.totalSoldiers.value}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.ironDark,
              ),
            ),
          ),
        ),
        // Selection ring indicator
        if (isSelected)
          Positioned(
            left: -6,
            top: -6,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.gold, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
