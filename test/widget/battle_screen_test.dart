import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/battle_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/screens/battle_screen.dart';

void main() {
  Company company(UnitRole role, int count) =>
      Company(composition: {role: count});

  // Build a battle with melee front and ranged/Peasants rear
  Battle mixedBattle() {
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
      final battle = mixedBattle();

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
      final battle = mixedBattle();

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
      final battle = mixedBattle();

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

  // ---------------------------------------------------------------------------
  // T040 / T041 / T042 / T043 — battleId-based BattleScreen via matchNotifierProvider
  // ---------------------------------------------------------------------------

  group('BattleScreen (battleId path)', () {
    // Build an ActiveBattle with known company compositions.
    ActiveBattle buildActiveBattle({
      String nodeId = 'j1',
      int attackerWarriors = 8,
      int defenderKnights = 5,
    }) {
      final attackerCo = Company(composition: {UnitRole.warrior: attackerWarriors});
      final defenderCo = Company(composition: {UnitRole.knight: defenderKnights});
      return ActiveBattle(
        nodeId: nodeId,
        attackerCompanyIds: const ['player_co0'],
        defenderCompanyIds: const ['ai_co0'],
        attackerOwnership: Ownership.player,
        battle: Battle(attackers: [attackerCo], defenders: [defenderCo]),
      );
    }

    // T040 — BattleScreen(battleId:) shows attackers and defenders for that battle
    testWidgets(
        'T040: shows correct attacker and defender companies for a given battleId',
        (tester) async {
      final ab = buildActiveBattle(attackerWarriors: 8, defenderKnights: 5);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchNotifierProvider.overrideWith(
              () => _BattleScreenFakeMatchNotifier(activeBattle: ab),
            ),
          ],
          child: MaterialApp(
            home: BattleScreen(battleId: ab.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both side labels must appear.
      expect(find.text('Attackers'), findsOneWidget);
      expect(find.text('Defenders'), findsOneWidget);
      // HP bars must be present for each side.
      expect(find.byKey(const Key('hp_bar')), findsWidgets);
      // "Next Round" button present.
      expect(find.text('Next Round'), findsOneWidget);
    });

    // T041 — tapping "Next Round" calls matchNotifier.advanceBattleRound(battleId)
    testWidgets(
        'T041: tapping Next Round calls advanceBattleRound with the correct battleId',
        (tester) async {
      final ab = buildActiveBattle();
      final notifier = _TrackingMatchNotifier(activeBattle: ab);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: BattleScreen(battleId: ab.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Next Round'));
      await tester.pump();

      expect(notifier.advancedBattleId, equals(ab.id));
    });

    // T042 — BattleScreen shows _BattleSummary when battle is resolved (gone from activeBattles)
    testWidgets(
        'T042: shows summary when ActiveBattle for battleId is gone from MatchState',
        (tester) async {
      final ab = buildActiveBattle();
      final notifier = _ResolvableMatchNotifier(activeBattle: ab);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: BattleScreen(battleId: ab.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Battle is active — Next Round button present.
      expect(find.text('Next Round'), findsOneWidget);

      // Simulate battle resolution (removed from activeBattles, outcome set).
      notifier.resolveBattle();
      await tester.pump();

      // Summary screen must appear — shows outcome text or "Return to Map".
      expect(find.text('Return to Map'), findsOneWidget);
    });

    // T043 — tapping "Next Round" via the real advanceBattleRound updates the
    // round number displayed in the AppBar.
    testWidgets(
        'T043: tapping Next Round with real advanceBattleRound updates '
        'round display from "Round 0" to "Round 1"',
        (tester) async {
      // Long-lived battle so it won't resolve in one round.
      final battle = Battle(
        attackers: [Company(composition: {UnitRole.warrior: 20})],
        defenders: [Company(composition: {UnitRole.warrior: 20})],
      );
      final ab = ActiveBattle(
        nodeId: 'j1',
        attackerCompanyIds: const ['p1'],
        defenderCompanyIds: const ['ai1'],
        attackerOwnership: Ownership.player,
        battle: battle,
      );

      final notifier = _RealAdvanceMatchNotifier(activeBattle: ab);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: BattleScreen(battleId: ab.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially at round 0.
      expect(find.text('Round 0'), findsOneWidget,
          reason: 'Battle must start at round 0');

      // Tap "Next Round" — real advanceBattleRound fires.
      await tester.tap(find.text('Next Round'));
      await tester.pump();
      await tester.pump();

      // Round number must have advanced to 1.
      expect(find.text('Round 1'), findsOneWidget,
          reason: 'Tapping Next Round must advance display to Round 1');
    });

    // T043b — tapping "Next Round" twice advances to round 2.
    testWidgets(
        'T043b: tapping Next Round twice advances to Round 2',
        (tester) async {
      final battle = Battle(
        attackers: [Company(composition: {UnitRole.warrior: 20})],
        defenders: [Company(composition: {UnitRole.warrior: 20})],
      );
      final ab = ActiveBattle(
        nodeId: 'j1',
        attackerCompanyIds: const ['p1'],
        defenderCompanyIds: const ['ai1'],
        attackerOwnership: Ownership.player,
        battle: battle,
      );

      final notifier = _RealAdvanceMatchNotifier(activeBattle: ab);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: BattleScreen(battleId: ab.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Next Round" twice.
      await tester.tap(find.text('Next Round'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Next Round'));
      await tester.pump();
      await tester.pump();

      // Must show Round 2.
      expect(find.text('Round 2'), findsOneWidget,
          reason: 'Two taps must advance display to Round 2');
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers for T040 / T041 / T042
// ---------------------------------------------------------------------------

/// Fake [MatchNotifier] that starts with one [ActiveBattle] injected.
/// Used by T040 to verify BattleScreen displays the correct companies.
class _BattleScreenFakeMatchNotifier extends MatchNotifier {
  final ActiveBattle _ab;
  _BattleScreenFakeMatchNotifier({required ActiveBattle activeBattle})
      : _ab = activeBattle;

  @override
  Future<MatchState> build() async {
    final base = await super.build();
    return base.copyWith(activeBattles: [_ab]);
  }
}

/// Fake [MatchNotifier] that records which battleId was passed to
/// [advanceBattleRound]. Used by T041.
class _TrackingMatchNotifier extends MatchNotifier {
  final ActiveBattle _ab;
  String? advancedBattleId;

  _TrackingMatchNotifier({required ActiveBattle activeBattle}) : _ab = activeBattle;

  @override
  Future<MatchState> build() async {
    final base = await super.build();
    return base.copyWith(activeBattles: [_ab]);
  }

  @override
  Future<void> advanceBattleRound(String battleId) async {
    advancedBattleId = battleId;
    // Don't actually advance — just record the call.
  }
}

/// Fake [MatchNotifier] whose battle can be "resolved" post-build.
/// Used by T042 to simulate the battle disappearing from activeBattles.
class _ResolvableMatchNotifier extends MatchNotifier {
  final ActiveBattle _ab;

  _ResolvableMatchNotifier({required ActiveBattle activeBattle})
      : _ab = activeBattle;

  @override
  Future<MatchState> build() async {
    final base = await super.build();
    return base.copyWith(activeBattles: [_ab]);
  }

  /// Remove the battle from state (simulates post-battle cleanup).
  /// The screen will fall back to its cached [_lastBattle] snapshot to render
  /// [_BattleSummary].
  void resolveBattle() {
    final current = state.valueOrNull;
    if (current == null) return;
    // Simply remove the active battle — no need to mutate _ab.
    state = AsyncData(current.copyWith(activeBattles: const []));
  }
}

/// Real [MatchNotifier] that starts with one [ActiveBattle] and uses the
/// genuine [advanceBattleRound] implementation.  Used by T043 / T043b to
/// verify that tapping "Next Round" actually updates the round display.
class _RealAdvanceMatchNotifier extends MatchNotifier {
  final ActiveBattle _ab;
  _RealAdvanceMatchNotifier({required ActiveBattle activeBattle})
      : _ab = activeBattle;

  @override
  Future<MatchState> build() async {
    final base = await super.build();
    return base.copyWith(
      match: base.match.copyWith(phase: MatchPhase.inBattle),
      activeBattles: [_ab],
    );
  }
}
