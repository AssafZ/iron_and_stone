import 'package:flutter/material.dart';
import 'package:iron_and_stone/domain/entities/company.dart';

/// Shown when all of the player's attacking force is eliminated.
///
/// Displays round count and surviving defender companies.
/// The "Return to Map" button pops the navigation stack.
final class DefeatScreen extends StatelessWidget {
  final int rounds;
  final List<Company> defenderSurvivors;

  const DefeatScreen({
    super.key,
    required this.rounds,
    required this.defenderSurvivors,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A1A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFFB71C1C),
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Defeat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB71C1C),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Battle resolved in $rounds round${rounds == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              if (defenderSurvivors.isNotEmpty) ...[
                Text(
                  'Defender survivors: ${defenderSurvivors.length} compan${defenderSurvivors.length == 1 ? 'y' : 'ies'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white60),
                ),
              ],
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
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
