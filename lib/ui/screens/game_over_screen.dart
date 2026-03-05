import 'package:flutter/material.dart';
import 'package:iron_and_stone/domain/rules/victory_checker.dart';

/// Shown when the game ends via Total Conquest (all castles owned by one side).
///
/// Displays whether the player won or lost and who won, then offers a
/// "Return to Main Menu" button that pops back to [MainMenuScreen].
final class GameOverScreen extends StatelessWidget {
  final MatchOutcome outcome;

  const GameOverScreen({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final isPlayerWin = outcome == MatchOutcome.playerWins;

    final Color bgColor =
        isPlayerWin ? const Color(0xFF1A3A1A) : const Color(0xFF3A1A1A);
    final Color accentColor =
        isPlayerWin ? const Color(0xFFFFD700) : const Color(0xFFB71C1C);
    final IconData icon =
        isPlayerWin ? Icons.emoji_events : Icons.shield_outlined;
    final String headline = isPlayerWin ? 'Victory!' : 'Defeat';
    final String winner =
        isPlayerWin ? 'You conquered all castles!' : 'The AI conquered all castles.';
    final String subtext = isPlayerWin
        ? 'Total Conquest achieved. All enemy castles are yours.'
        : 'All your castles have fallen. Better luck next time.';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, color: accentColor, size: 80),
              const SizedBox(height: 24),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                winner,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtext,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 56),
              ElevatedButton(
                key: const ValueKey('game_over_main_menu_button'),
                onPressed: () {
                  // Pop back all the way to the main menu.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPlayerWin
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF7B1FA2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Return to Main Menu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
