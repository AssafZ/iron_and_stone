import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/terrain_bonus.dart';

void main() {
  group('TerrainBonus', () {
    Company company(UnitRole role, int count) =>
        Company(composition: {role: count});

    group('Knight road charge (2× DMG on road)', () {
      test('Knight road 2× DMG returns 80 total for 1 Knight', () {
        final ctx = const BattleContext(isOnRoad: true, isDefendingCastle: false);

        final bonus = TerrainBonus.applyBonus(
          role: UnitRole.knight,
          count: 1,
          context: ctx,
        );

        // Base Knight DMG = 40; road charge = 2× = 80
        expect(bonus, equals(80));
      });

      test('Knight NOT on road does NOT get 2× bonus', () {
        final ctx = const BattleContext(isOnRoad: false, isDefendingCastle: false);

        final bonus = TerrainBonus.applyBonus(
          role: UnitRole.knight,
          count: 1,
          context: ctx,
        );

        expect(bonus, equals(40)); // base damage only
      });

      test('multiple Knights on road scale correctly (2 Knights × 80 = 160)',
          () {
        final ctx = const BattleContext(isOnRoad: true, isDefendingCastle: false);

        final bonus = TerrainBonus.applyBonus(
          role: UnitRole.knight,
          count: 2,
          context: ctx,
        );

        expect(bonus, equals(160));
      });
    });

    group('Archer High Ground (2× DMG + 75% DR when no Warriors present)', () {
      test('highGroundActive returns true when no Warriors present', () {
        final attackers = [company(UnitRole.knight, 2)];
        expect(TerrainBonus.highGroundActive(attackers: attackers), isTrue);
      });

      test('highGroundActive returns false when Warriors present', () {
        final attackers = [
          Company(composition: {
            UnitRole.warrior: 3,
            UnitRole.knight: 1,
          }),
        ];
        expect(TerrainBonus.highGroundActive(attackers: attackers), isFalse);
      });

      test('highGroundActive returns true for empty attacker company (no Warriors)',
          () {
        final attackers = [company(UnitRole.archer, 5)]; // defenders are testing
        expect(TerrainBonus.highGroundActive(attackers: attackers), isTrue);
      });

      test('Archers defending castle with High Ground deal 2× damage', () {
        final ctx = const BattleContext(
          isOnRoad: false,
          isDefendingCastle: true,
          highGroundActive: true,
        );

        final bonus = TerrainBonus.applyBonus(
          role: UnitRole.archer,
          count: 1,
          context: ctx,
        );

        // Base Archer DMG = 25; High Ground 2× = 50
        expect(bonus, equals(50));
      });

      test('Archers defending castle with High Ground apply 75% DR', () {
        final incomingDamage = 100;
        final ctx = const BattleContext(
          isOnRoad: false,
          isDefendingCastle: true,
          highGroundActive: true,
        );

        final reducedDamage = TerrainBonus.applyDamageReduction(
          incomingDamage: incomingDamage,
          context: ctx,
        );

        // 75% DR: 100 × (1 - 0.75) = 25
        expect(reducedDamage, equals(25));
      });

      test('High Ground negated when Warriors present — Archers get base damage only', () {
        final ctx = const BattleContext(
          isOnRoad: false,
          isDefendingCastle: true,
          highGroundActive: false, // Warriors present → negated
        );

        final bonus = TerrainBonus.applyBonus(
          role: UnitRole.archer,
          count: 1,
          context: ctx,
        );

        expect(bonus, equals(25)); // base damage only
      });

      test('High Ground negated — no DR applied', () {
        final incomingDamage = 100;
        final ctx = const BattleContext(
          isOnRoad: false,
          isDefendingCastle: true,
          highGroundActive: false,
        );

        final reducedDamage = TerrainBonus.applyDamageReduction(
          incomingDamage: incomingDamage,
          context: ctx,
        );

        expect(reducedDamage, equals(100)); // no reduction
      });
    });

    group('Catapult Wall Breaker', () {
      test('applyWallBreaker removes Archer High Ground bonus flag', () {
        final attackers = [company(UnitRole.catapult, 1)];
        final defenders = [company(UnitRole.archer, 10)];
        final battle = Battle(
          attackers: attackers,
          defenders: defenders,
          highGroundActive: true, // initially active
        );

        final after = TerrainBonus.applyWallBreaker(battle);

        expect(after.highGroundActive, isFalse);
      });

      test('applyWallBreaker with no Catapults does NOT remove High Ground', () {
        final attackers = [company(UnitRole.knight, 1)];
        final defenders = [company(UnitRole.archer, 10)];
        final battle = Battle(
          attackers: attackers,
          defenders: defenders,
          highGroundActive: true,
        );

        final after = TerrainBonus.applyWallBreaker(battle);

        expect(after.highGroundActive, isTrue);
      });

      test(
          'High Ground absent in round 2 and beyond after Wall Breaker (even with no Warriors)',
          () {
        // Verify: once highGroundActive is false, it stays false regardless of Warriors
        final attackers = [company(UnitRole.catapult, 1)];
        final defenders = [company(UnitRole.archer, 10)];
        final battle = Battle(
          attackers: attackers,
          defenders: defenders,
          highGroundActive: true,
        );

        // Round 1: Catapult removes high ground
        final afterRound1 = TerrainBonus.applyWallBreaker(battle);
        expect(afterRound1.highGroundActive, isFalse);

        // Round 2: high ground should remain inactive
        final afterRound2 = TerrainBonus.applyWallBreaker(afterRound1);
        expect(afterRound2.highGroundActive, isFalse);
      });
    });
  });
}
