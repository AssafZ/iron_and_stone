import 'package:flutter/material.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

/// An animated map indicator shown at a battle node while a battle is in progress.
///
/// Renders a pulsing crossed-swords icon with a red overlay to draw the player's
/// attention. Tapping the indicator fires [onTap] (wired to open [BattleScreen]).
///
/// ## Performance
/// The pulse animation is isolated inside a [RepaintBoundary] so the animation
/// repaints never propagate to the surrounding map stack.
///
/// ## Tap target
/// The outer [SizedBox] is always 44 × 44 pt, satisfying both the Material and
/// HIG minimum tap-target requirements.
class BattleIndicator extends StatefulWidget {
  /// The ID of the [ActiveBattle] this indicator represents.
  final String battleId;

  /// Called when the user taps the indicator.
  final VoidCallback onTap;

  const BattleIndicator({
    super.key,
    required this.battleId,
    required this.onTap,
  });

  @override
  State<BattleIndicator> createState() => _BattleIndicatorState();
}

class _BattleIndicatorState extends State<BattleIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: widget.onTap,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              return Opacity(
                opacity: _pulse.value,
                child: child,
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.bloodRed.withAlpha(200),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x998B1A1A),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '⚔',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
