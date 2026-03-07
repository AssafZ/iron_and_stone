import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Battle _makeBattle() => Battle(
      attackers: [
        Company(composition: {UnitRole.warrior: 5}),
      ],
      defenders: [
        Company(composition: {UnitRole.archer: 3}),
      ],
    );

// ---------------------------------------------------------------------------
// T005: ActiveBattle entity tests
// ---------------------------------------------------------------------------

void main() {
  group('ActiveBattle', () {
    group('id derivation (T005)', () {
      test('id equals "battle_<nodeId>"', () {
        final battle = ActiveBattle(
          nodeId: 'junction_mid',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: _makeBattle(),
        );
        expect(battle.id, equals('battle_junction_mid'));
      });

      test('id reflects the nodeId regardless of node name', () {
        final battle = ActiveBattle(
          nodeId: 'ai_castle',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: _makeBattle(),
        );
        expect(battle.id, equals('battle_ai_castle'));
      });
    });

    group('construction', () {
      test('fields are stored correctly', () {
        final b = _makeBattle();
        final ab = ActiveBattle(
          nodeId: 'node_42',
          attackerCompanyIds: ['p1', 'p2'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: b,
        );
        expect(ab.nodeId, equals('node_42'));
        expect(ab.attackerCompanyIds, equals(['p1', 'p2']));
        expect(ab.defenderCompanyIds, equals(['ai1']));
        expect(ab.attackerOwnership, equals(Ownership.player));
        expect(ab.battle, same(b));
      });

      test('attacker and defender ID lists are defensive copies', () {
        final attackerIds = ['p1'];
        final defenderIds = ['ai1'];
        final ab = ActiveBattle(
          nodeId: 'node_x',
          attackerCompanyIds: attackerIds,
          defenderCompanyIds: defenderIds,
          attackerOwnership: Ownership.player,
          battle: _makeBattle(),
        );
        attackerIds.add('p2');
        defenderIds.add('ai2');
        // Internal lists must not reflect external mutations.
        expect(ab.attackerCompanyIds, hasLength(1));
        expect(ab.defenderCompanyIds, hasLength(1));
      });
    });

    group('copyWith', () {
      test('copyWith returns a new instance with updated battle', () {
        final original = ActiveBattle(
          nodeId: 'node_1',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: _makeBattle(),
        );
        final updatedBattle = _makeBattle();
        final copy = original.copyWith(battle: updatedBattle);
        expect(copy.battle, same(updatedBattle));
        expect(copy.nodeId, equals(original.nodeId));
        expect(copy.id, equals(original.id));
      });

      test('copyWith with attackerCompanyIds replaces the list', () {
        final original = ActiveBattle(
          nodeId: 'node_1',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: _makeBattle(),
        );
        final copy = original.copyWith(attackerCompanyIds: ['p1', 'p2']);
        expect(copy.attackerCompanyIds, equals(['p1', 'p2']));
      });
    });

    group('toString', () {
      test('toString includes id and round info', () {
        final ab = ActiveBattle(
          nodeId: 'my_node',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: _makeBattle(),
        );
        final s = ab.toString();
        expect(s, contains('battle_my_node'));
      });
    });
  });
}
