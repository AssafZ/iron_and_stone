import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/advance_battle.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  group('AdvanceBattle', () {
    // T023a: AdvanceBattle.advance() advances the battle by one round
    group('T023a: advance() increases roundNumber by 1', () {
      test(
        'T023a: calling advance on an ongoing ActiveBattle increments roundNumber',
        () {
          final battle = Battle(
            attackers: [Company(composition: {UnitRole.warrior: 10})],
            defenders: [Company(composition: {UnitRole.warrior: 10})],
          );
          final activeBattle = ActiveBattle(
            nodeId: 'jn',
            attackerCompanyIds: ['p1'],
            defenderCompanyIds: ['ai1'],
            attackerOwnership: Ownership.player,
            battle: battle,
          );

          final result = const AdvanceBattle().advance(activeBattle);

          expect(
            result.battle.roundNumber,
            equals(battle.roundNumber + 1),
            reason: 'advance() must resolve exactly one round',
          );
        },
      );

      test(
        'T023a: advance() returns a new ActiveBattle with updated battle state',
        () {
          final battle = Battle(
            attackers: [Company(composition: {UnitRole.warrior: 10})],
            defenders: [Company(composition: {UnitRole.warrior: 10})],
          );
          final activeBattle = ActiveBattle(
            nodeId: 'jn',
            attackerCompanyIds: ['p1'],
            defenderCompanyIds: ['ai1'],
            attackerOwnership: Ownership.player,
            battle: battle,
          );

          final result = const AdvanceBattle().advance(activeBattle);

          // The returned battle must not be the same object
          expect(result.battle, isNot(same(battle)));
          // nodeId, company IDs and attackerOwnership must be unchanged
          expect(result.nodeId, equals(activeBattle.nodeId));
          expect(result.attackerCompanyIds, equals(activeBattle.attackerCompanyIds));
          expect(result.defenderCompanyIds, equals(activeBattle.defenderCompanyIds));
          expect(result.attackerOwnership, equals(activeBattle.attackerOwnership));
        },
      );

      test(
        'T023a: advance() on an already-resolved battle does not change roundNumber',
        () {
          final battle = Battle(
            attackers: [Company(composition: {UnitRole.warrior: 10})],
            defenders: [Company(composition: {UnitRole.peasant: 0})],
            outcome: BattleOutcome.attackersWin,
            roundNumber: 3,
          );
          final activeBattle = ActiveBattle(
            nodeId: 'jn',
            attackerCompanyIds: ['p1'],
            defenderCompanyIds: ['ai1'],
            attackerOwnership: Ownership.player,
            battle: battle,
          );

          final result = const AdvanceBattle().advance(activeBattle);

          // Already resolved — must not re-run a round
          expect(result.battle.roundNumber, equals(3));
          expect(result.battle.outcome, equals(BattleOutcome.attackersWin));
        },
      );
    });
  });
}
