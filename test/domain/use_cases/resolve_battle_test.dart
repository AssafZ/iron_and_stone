import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/resolve_battle.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  Company company(UnitRole role, int count) =>
      Company(composition: {role: count});

  // Helper castle node for castle-assault tests
  CastleNode castleNode({
    String id = 'c1',
    Ownership ownership = Ownership.ai,
  }) =>
      CastleNode(id: id, x: 0, y: 0, ownership: ownership);

  group('ResolveBattle — basic outcome', () {
    test('attackers win when all defenders are eliminated', () {
      // 10 Knights attack 2 Peasants — overwhelming victory
      final attackerCo = company(UnitRole.knight, 10);
      final defenderCo = company(UnitRole.peasant, 2);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
      );

      expect(result.outcome, equals(BattleOutcome.attackersWin));
      expect(result.attackerSurvivors, isNotEmpty);
      expect(result.defenderSurvivors, isEmpty);
    });

    test('defenders win when all attackers are eliminated', () {
      // 2 Peasants attack 10 Knights
      final attackerCo = company(UnitRole.peasant, 2);
      final defenderCo = company(UnitRole.knight, 10);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
      );

      expect(result.outcome, equals(BattleOutcome.defendersWin));
      expect(result.attackerSurvivors, isEmpty);
      expect(result.defenderSurvivors, isNotEmpty);
    });

    test('returns correct survivor counts', () {
      // 1 Warrior (15 DMG, 50 HP) vs 1 Catapult (60 DMG, 150 HP)
      // Warrior needs ceil(150/15) = 10 rounds, Catapult needs ceil(50/60) = 1 round
      // Catapult wins in round 1
      final attackerCo = company(UnitRole.warrior, 1);
      final defenderCo = company(UnitRole.catapult, 1);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
      );

      expect(result.outcome, equals(BattleOutcome.defendersWin));
      expect(result.attackerSurvivors, isEmpty);
    });
  });

  group('ResolveBattle — draw outcome (T046a)', () {
    test('BattleOutcome.draw when both sides eliminated simultaneously', () {
      // Knight (100 HP, 40 DMG) vs Knight (100 HP, 40 DMG)
      // After 3 rounds: 3×40 = 120 DMG > 100 HP → both die simultaneously
      final attackerCo = company(UnitRole.knight, 1);
      final defenderCo = company(UnitRole.knight, 1);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
      );

      expect(result.outcome, equals(BattleOutcome.draw));
    });

    test('no castle ownership transfer on draw', () {
      final attackerCo = company(UnitRole.knight, 1);
      final defenderCo = company(UnitRole.knight, 1);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      // Use road collision so high ground is not triggered (symmetric fight → draw)
      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
      );

      expect(result.outcome, equals(BattleOutcome.draw));
      // No ownership transfer on draw (or on road collision)
      expect(result.castleOwnershipTransfer, isNull);
    });

    test('attackerSurvivors and defenderSurvivors both empty on draw', () {
      final attackerCo = company(UnitRole.knight, 1);
      final defenderCo = company(UnitRole.knight, 1);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
      );

      expect(result.outcome, equals(BattleOutcome.draw));
      expect(result.attackerSurvivors, isEmpty);
      expect(result.defenderSurvivors, isEmpty);
    });
  });

  group('ResolveBattle — castle ownership transfer', () {
    test('castle ownership transfers to attacker on defender elimination', () {
      final attackerCo = company(UnitRole.knight, 10);
      final defenderCo = company(UnitRole.peasant, 1);
      final node = castleNode(id: 'ai_castle', ownership: Ownership.ai);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: BattleTrigger(
          kind: BattleTriggerKind.castleAssault,
          location: node,
          companyIds: ['a1', 'd1'],
        ),
        attackerOwnership: Ownership.player,
      );

      expect(result.outcome, equals(BattleOutcome.attackersWin));
      expect(result.castleOwnershipTransfer, isNotNull);
      expect(result.castleOwnershipTransfer!.castleId, equals('ai_castle'));
      expect(result.castleOwnershipTransfer!.newOwner, equals(Ownership.player));
    });

    test('castle ownership does NOT transfer on road collision', () {
      final attackerCo = company(UnitRole.knight, 10);
      final defenderCo = company(UnitRole.peasant, 1);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
        attackerOwnership: Ownership.player,
      );

      expect(result.outcome, equals(BattleOutcome.attackersWin));
      expect(result.castleOwnershipTransfer, isNull);
    });
  });

  group('ResolveBattle — reinforcement waves (FR-021)', () {
    test('addReinforcement adds Company to the appropriate side', () {
      final attackerCo = company(UnitRole.warrior, 5);
      final defenderCo = company(UnitRole.warrior, 50);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final reinforcement = company(UnitRole.knight, 3);
      final updated = ResolveBattle.addReinforcement(
        battle: battle,
        reinforcement: reinforcement,
        side: BattleSide.attackers,
      );

      expect(updated.attackers.length, equals(2));
      expect(updated.attackers.last.composition[UnitRole.knight], equals(3));
    });

    test('addReinforcement to defenders side adds to defenders', () {
      final attackerCo = company(UnitRole.warrior, 50);
      final defenderCo = company(UnitRole.warrior, 5);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final reinforcement = company(UnitRole.archer, 10);
      final updated = ResolveBattle.addReinforcement(
        battle: battle,
        reinforcement: reinforcement,
        side: BattleSide.defenders,
      );

      expect(updated.defenders.length, equals(2));
      expect(updated.defenders.last.composition[UnitRole.archer], equals(10));
    });
  });

  // T058a — Company zero-survivor cleanup
  group('ResolveBattle — Company zero-survivor cleanup (T058a)', () {
    test('companies with zero survivors are removed from result', () {
      // 10 Knights vs 2 Peasants: all Peasants eliminated
      final attackerCo = company(UnitRole.knight, 10);
      final defenderCo = company(UnitRole.peasant, 2);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
      );

      // Defender company should have 0 soldiers → should be in defenderSurvivors as empty or absent
      expect(result.defenderSurvivors, isEmpty);
    });

    test('surviving companies have non-zero soldier counts', () {
      // 1 Warrior (50 HP, 15 DMG) vs 50 Peasants (10 HP each, 0 DMG)
      // Warrior wins — survivors should all have > 0 soldiers
      final attackerCo = company(UnitRole.warrior, 1);
      final defenderCo = company(UnitRole.peasant, 50);

      final battle = Battle(
        attackers: [attackerCo],
        defenders: [defenderCo],
      );

      final result = const ResolveBattle().resolve(
        battle: battle,
        trigger: const BattleTrigger(
          kind: BattleTriggerKind.roadCollision,
          location: RoadJunctionNode(id: 'j1', x: 0, y: 0),
          companyIds: ['a1', 'd1'],
        ),
      );

      for (final co in result.attackerSurvivors) {
        expect(co.totalSoldiers.value, greaterThan(0));
      }
    });
  });
}
