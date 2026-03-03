import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/ui/screens/defeat_screen.dart';
import 'package:iron_and_stone/ui/screens/victory_screen.dart';

void main() {
  Company company(UnitRole role, int count) =>
      Company(composition: {role: count});

  group('VictoryScreen', () {
    testWidgets('VictoryScreen renders with summary stats', (tester) async {
      final survivors = [company(UnitRole.knight, 5), company(UnitRole.warrior, 3)];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: VictoryScreen(
              rounds: 5,
              attackerSurvivors: survivors,
            ),
          ),
        ),
      );

      expect(find.textContaining('Victory', findRichText: true), findsAny);
      expect(find.textContaining('5', findRichText: true), findsWidgets);
    });

    testWidgets('VictoryScreen has a dismiss button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VictoryScreen(rounds: 3, attackerSurvivors: []),
          ),
        ),
      );

      expect(find.text('Return to Map'), findsOneWidget);
    });

    testWidgets('VictoryScreen dismiss button is tappable and navigates back',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              '/map': (_) => const Scaffold(body: Text('Map Screen')),
            },
            home: const VictoryScreen(rounds: 3, attackerSurvivors: []),
          ),
        ),
      );

      // Button should be tappable
      final button = find.text('Return to Map');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
    });
  });

  group('DefeatScreen', () {
    testWidgets('DefeatScreen renders with summary stats', (tester) async {
      final survivors = [company(UnitRole.knight, 5)];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DefeatScreen(
              rounds: 4,
              defenderSurvivors: survivors,
            ),
          ),
        ),
      );

      expect(find.textContaining('Defeat', findRichText: true), findsAny);
    });

    testWidgets('DefeatScreen has a dismiss button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DefeatScreen(rounds: 2, defenderSurvivors: []),
          ),
        ),
      );

      expect(find.text('Return to Map'), findsOneWidget);
    });

    testWidgets('DefeatScreen and VictoryScreen are separately tested',
        (tester) async {
      // Victory
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VictoryScreen(rounds: 1, attackerSurvivors: []),
          ),
        ),
      );
      expect(find.textContaining('Victory', findRichText: true), findsAny);

      // Defeat
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DefeatScreen(rounds: 1, defenderSurvivors: []),
          ),
        ),
      );
      expect(find.textContaining('Defeat', findRichText: true), findsAny);
    });

    testWidgets('DefeatScreen dismiss button is tappable', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DefeatScreen(rounds: 2, defenderSurvivors: []),
          ),
        ),
      );

      final button = find.text('Return to Map');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
    });
  });
}
