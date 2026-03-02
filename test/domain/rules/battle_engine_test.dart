import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/battle_engine.dart';

void main() {
  group('BattleEngine', () {
    // Helper: create a Company with a single role
    Company company(UnitRole role, int count) =>
        Company(composition: {role: count});

    group('resolveRound — basic damage', () {
      test('Warriors deal 15 DMG per soldier each round', () {
        // 1 Warrior (15 DMG) vs 1 Knight (100 HP)
        final attackerCompany = company(UnitRole.warrior, 1);
        final defenderCompany = company(UnitRole.knight, 1);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        // Knight has 100 HP; Warrior deals 15 DMG → Knight should have 85 HP remaining
        // (represented by 1 Knight still alive since HP > 0)
        expect(result.updatedBattle.defenders.isNotEmpty, isTrue);
        expect(result.roundDamageToDefenders, equals(15));
      });

      test('Knights deal 40 DMG per soldier each round', () {
        final attackerCompany = company(UnitRole.knight, 1);
        final defenderCompany = company(UnitRole.warrior, 3); // 3 × 50 HP = 150 HP total
        // Use castleAssault so the Knight road-charge (2×) does NOT apply
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
          kind: BattleKind.castleAssault,
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        expect(result.roundDamageToDefenders, equals(40));
      });

      test('Archers deal 25 DMG per soldier each round', () {
        final attackerCompany = company(UnitRole.archer, 1);
        final defenderCompany = company(UnitRole.warrior, 10);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        expect(result.roundDamageToDefenders, equals(25));
      });

      test('Catapults deal 60 DMG per soldier each round', () {
        final attackerCompany = company(UnitRole.catapult, 1);
        final defenderCompany = company(UnitRole.warrior, 10);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        expect(result.roundDamageToDefenders, equals(60));
      });

      test('Peasants deal 0 DMG per soldier each round', () {
        final attackerCompany = company(UnitRole.peasant, 5);
        final defenderCompany = company(UnitRole.warrior, 5);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        expect(result.roundDamageToDefenders, equals(0));
      });

      test('multiple soldiers multiply damage', () {
        // 3 Warriors × 15 DMG = 45 DMG against defenders
        final attackerCompany = company(UnitRole.warrior, 3);
        final defenderCompany = company(UnitRole.knight, 1);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        expect(result.roundDamageToDefenders, equals(45));
      });
    });

    group('resolveRound — unit elimination', () {
      test('units at 0 HP are removed before next round', () {
        // 1 Warrior (15 DMG) × 4 rounds kills a 50 HP Warrior... 
        // but in ONE round: 2 Catapults (60 DMG each = 120 DMG) kill Warriors at 50 HP each
        // 3 Warriors total: 150 HP. 2 Catapults = 120 DMG → 2 Warriors eliminated (100 HP gone)
        // remaining: 1 Warrior with 50 HP
        final attackerCompany = company(UnitRole.catapult, 2);
        final defenderCompany = company(UnitRole.warrior, 3);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        // 2 Catapults deal 120 DMG; 2 Warriors eliminated (100 HP), 1 remains (50 HP - 20 damage)
        // But since damage is applied per-unit based on HP, we check soldiers remaining
        // 120 DMG kills floor(120/50) = 2 warriors exactly, with 20 remaining DMG
        expect(result.updatedBattle.defenders.first.totalSoldiers.value,
            lessThan(3));
      });

      test('all defenders eliminated returns BattleOutcome.attackersWin', () {
        // Knight (100 HP, 40 DMG) vs Peasant (10 HP, 0 DMG)
        // 1 Knight deals 40 DMG; kills 4 Peasants (10 HP each)
        final attackerCompany = company(UnitRole.knight, 1);
        final defenderCompany = company(UnitRole.peasant, 4);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        // Resolve rounds until outcome
        var current = battle;
        BattleRoundResult? lastResult;
        for (var i = 0; i < 20; i++) {
          lastResult = engine.resolveRound(current);
          current = lastResult.updatedBattle;
          if (current.outcome != null) break;
        }

        expect(current.outcome, equals(BattleOutcome.attackersWin));
      });

      test('all attackers eliminated returns BattleOutcome.defendersWin', () {
        // 3 Knights defending vs 1 Peasant attacking
        // Peasant deals 0 DMG; Knights deal 40 DMG × 3 = 120 DMG
        // Peasant has 10 HP → eliminated in 1 round
        final attackerCompany = company(UnitRole.peasant, 1);
        final defenderCompany = company(UnitRole.knight, 3);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        var current = battle;
        for (var i = 0; i < 20; i++) {
          final result = engine.resolveRound(current);
          current = result.updatedBattle;
          if (current.outcome != null) break;
        }

        expect(current.outcome, equals(BattleOutcome.defendersWin));
      });

      test('mutual destruction — draw when both sides eliminated simultaneously',
          () {
        // 1 Knight (100 HP, 40 DMG) vs 1 Knight (100 HP, 40 DMG)
        // Each round: both deal 40 DMG → after 3 rounds (3×40=120 > 100) both die
        // BUT: simultaneous — must result in draw
        final attackerCompany = company(UnitRole.knight, 1);
        final defenderCompany = company(UnitRole.knight, 1);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        var current = battle;
        for (var i = 0; i < 20; i++) {
          final result = engine.resolveRound(current);
          current = result.updatedBattle;
          if (current.outcome != null) break;
        }

        expect(current.outcome, equals(BattleOutcome.draw));
      });
    });

    group('resolveRound — round log', () {
      test('round log is appended with each resolved round', () {
        final attackerCompany = company(UnitRole.warrior, 5);
        final defenderCompany = company(UnitRole.warrior, 5);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        expect(result.updatedBattle.roundLog, isNotEmpty);
        expect(result.updatedBattle.roundNumber, equals(1));
      });

      test('round number increments on each call', () {
        final attackerCompany = company(UnitRole.warrior, 2);
        final defenderCompany = company(UnitRole.warrior, 10);
        var current = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        current = engine.resolveRound(current).updatedBattle;
        current = engine.resolveRound(current).updatedBattle;

        expect(current.roundNumber, equals(2));
      });
    });

    group('resolveRound — simultaneous damage', () {
      test('damage is applied simultaneously — both sides take damage each round',
          () {
        // 5 Warriors vs 5 Warriors: both should deal damage simultaneously
        final attackerCompany = company(UnitRole.warrior, 5);
        final defenderCompany = company(UnitRole.warrior, 5);
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );

        final engine = BattleEngine();
        final result = engine.resolveRound(battle);

        // Both sides should have taken damage
        expect(result.roundDamageToAttackers, greaterThan(0));
        expect(result.roundDamageToDefenders, greaterThan(0));
      });
    });
  });
}
