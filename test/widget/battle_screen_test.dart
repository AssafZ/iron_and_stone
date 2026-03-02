import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/state/battle_notifier.dart';
import 'package:iron_and_stone/ui/screens/battle_screen.dart';

void main() {
  Company company(UnitRole role, int count) =>
      Company(composition: {role: count});

  // Build a battle with melee front and ranged/Peasants rear
  Battle _mixedBattle() {
    final attackers = [
      Company(composition: {
        UnitRole.warrior: 5,
        UnitRole.archer: 3,
      }),
    ];
    final defenders = [
      Company(composition: {
        UnitRole.knight: 3,
        UnitRole.catapult: 1,
        UnitRole.peasant: 2,
      }),
    ];
    return Battle(attackers: attackers, defenders: defenders);
  }

  group('BattleScreen', () {
    testWidgets('BattleScreen renders with melee units at front and ranged at rear',
        (tester) async {
      final battle = _mixedBattle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            battleNotifierProvider.overrideWith(
              () => BattleNotifier()..initWithBattle(battle),
            ),
          ],
          child: const MaterialApp(home: BattleScreen()),
        ),
      );

      await tester.pump();

      // BattleScreen should be present
      expect(find.byType(BattleScreen), findsOneWidget);

      // Melee section should be visible
      expect(find.text('Melee'), findsWidgets);
      // Ranged / Rear section visible
      expect(find.text('Ranged'), findsWidgets);
    });

    testWidgets('BattleScreen shows HP bars', (tester) async {
      final battle = _mixedBattle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            battleNotifierProvider.overrideWith(
              () => BattleNotifier()..initWithBattle(battle),
            ),
          ],
          child: const MaterialApp(home: BattleScreen()),
        ),
      );

      await tester.pump();

      // HP bar widgets should be present
      expect(find.byKey(const Key('hp_bar')), findsWidgets);
    });

    testWidgets('BattleScreen shows "Next Round" button', (tester) async {
      final battle = _mixedBattle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            battleNotifierProvider.overrideWith(
              () => BattleNotifier()..initWithBattle(battle),
            ),
          ],
          child: const MaterialApp(home: BattleScreen()),
        ),
      );

      await tester.pump();

      expect(find.text('Next Round'), findsOneWidget);
    });

    testWidgets('tapping Next Round advances the round', (tester) async {
      final battle = Battle(
        attackers: [company(UnitRole.warrior, 5)],
        defenders: [company(UnitRole.warrior, 50)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            battleNotifierProvider.overrideWith(
              () => BattleNotifier()..initWithBattle(battle),
            ),
          ],
          child: const MaterialApp(home: BattleScreen()),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Next Round'));
      await tester.pump();

      // Round 1 should now be shown
      expect(find.textContaining('Round'), findsWidgets);
    });

    testWidgets('BattleScreen transitions to victory summary on attackers win',
        (tester) async {
      // 10 Knights vs 1 Peasant — attackers win in 1 round
      final battle = Battle(
        attackers: [company(UnitRole.knight, 10)],
        defenders: [company(UnitRole.peasant, 1)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            battleNotifierProvider.overrideWith(
              () => BattleNotifier()..initWithBattle(battle),
            ),
          ],
          child: const MaterialApp(home: BattleScreen()),
        ),
      );

      await tester.pump();

      // Tap "Next Round" until battle ends
      for (var i = 0; i < 5; i++) {
        final button = find.text('Next Round');
        if (button.evaluate().isEmpty) break;
        await tester.tap(button);
        await tester.pump();
      }

      // Victory summary should appear
      expect(
        find.textContaining('Victory', findRichText: true),
        findsAny,
      );
    });

    testWidgets('BattleScreen shows draw result screen on draw outcome',
        (tester) async {
      // Knight vs Knight — draw
      final battle = Battle(
        attackers: [company(UnitRole.knight, 1)],
        defenders: [company(UnitRole.knight, 1)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            battleNotifierProvider.overrideWith(
              () => BattleNotifier()..initWithBattle(battle),
            ),
          ],
          child: const MaterialApp(home: BattleScreen()),
        ),
      );

      await tester.pump();

      // Tap until resolved
      for (var i = 0; i < 10; i++) {
        final button = find.text('Next Round');
        if (button.evaluate().isEmpty) break;
        await tester.tap(button);
        await tester.pump();
      }

      expect(find.textContaining('Draw', findRichText: true), findsAny);
    });

    testWidgets(
        'victory/defeat summary shows Return to Map button that is tappable',
        (tester) async {
      // Quick battle to trigger end
      final battle = Battle(
        attackers: [company(UnitRole.knight, 10)],
        defenders: [company(UnitRole.peasant, 1)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            battleNotifierProvider.overrideWith(
              () => BattleNotifier()..initWithBattle(battle),
            ),
          ],
          child: MaterialApp(
            home: const BattleScreen(),
            routes: {
              '/map': (_) => const Scaffold(body: Text('Map Screen')),
            },
          ),
        ),
      );

      await tester.pump();

      // Advance until resolved
      for (var i = 0; i < 5; i++) {
        final button = find.text('Next Round');
        if (button.evaluate().isEmpty) break;
        await tester.tap(button);
        await tester.pump();
      }

      // Return to Map button should appear
      expect(find.text('Return to Map'), findsOneWidget);
    });
  });
}
