import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/ui/screens/map_screen.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

/// The main menu screen — entry point of the game.
///
/// No game logic lives here; it simply provides a "New Game" button that
/// navigates to [MapScreen].
class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.parchment,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              const Text(
                'Iron and Stone',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ironDark,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A Medieval Strategy Game',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.stone,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 64),
              // New Game button
              ElevatedButton(
                key: const ValueKey('new_game_button'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MapScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bloodRed,
                  foregroundColor: AppTheme.parchment,
                  minimumSize: const Size(220, 54),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('New Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
