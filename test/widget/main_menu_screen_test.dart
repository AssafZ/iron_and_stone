// T032 — Failing widget tests for MainMenuScreen
// Red-Green-Refactor: these tests must FAIL before implementation exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/ui/screens/main_menu_screen.dart';
import 'package:iron_and_stone/ui/screens/map_screen.dart';

void main() {
  group('MainMenuScreen', () {
    testWidgets('"New Game" button is present and tappable', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MainMenuScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('new_game_button')), findsOneWidget);
      expect(find.text('New Game'), findsOneWidget);
    });

    testWidgets('"New Game" button routes to MapScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const MainMenuScreen(),
            routes: {
              '/map': (_) => const MapScreen(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('new_game_button')));
      await tester.pumpAndSettle();

      // After navigation, MapScreen is visible.
      expect(find.byType(MapScreen), findsOneWidget);
    });
  });
}
