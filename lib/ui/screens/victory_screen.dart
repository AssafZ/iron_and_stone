import 'package:flutter/material.dart';
import 'package:iron_and_stone/domain/entities/company.dart';

/// Shown when the player's attacking force eliminates all defenders.
///
/// Displays round count and surviving attacker companies.
/// The "Return to Map" button pops the navigation stack.
final class VictoryScreen extends StatelessWidget {
  final int rounds;
  final List<Company> attackerSurvivors;

  const VictoryScreen({
    super.key,
    required this.rounds,
    required this.attackerSurvivors,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD700),
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Victory!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Battle resolved in $rounds round${rounds == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              if (attackerSurvivors.isNotEmpty) ...[
                Text(
                  'Surviving companies: ${attackerSurvivors.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white60),
                ),
                const SizedBox(height: 8),
                ...attackerSurvivors.map(
                  (c) => Text(
                    '  • ${c.totalSoldiers.value} soldiers',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white54),
                  ),
                ),
              ],
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Return to Map',
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
