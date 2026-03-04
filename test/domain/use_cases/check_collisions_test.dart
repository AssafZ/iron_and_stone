import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _playerCastle = CastleNode(
  id: 'player_castle',
  x: 0.0,
  y: 0.0,
  ownership: Ownership.player,
);

const _aiCastle = CastleNode(
  id: 'ai_castle',
  x: 300.0,
  y: 0.0,
  ownership: Ownership.ai,
);

const _junction = RoadJunctionNode(id: 'junction_mid', x: 150.0, y: 0.0);

GameMap _makeMap() {
  return GameMap(
    nodes: [_playerCastle, _junction, _aiCastle],
    edges: [
      RoadEdge(from: _playerCastle, to: _junction, length: 150.0),
      RoadEdge(from: _junction, to: _playerCastle, length: 150.0),
      RoadEdge(from: _junction, to: _aiCastle, length: 150.0),
      RoadEdge(from: _aiCastle, to: _junction, length: 150.0),
    ],
  );
}

CompanyOnMap _makeCompany({
  required String id,
  required Ownership ownership,
  required MapNode currentNode,
  MapNode? destination,
  double progress = 0.0,
}) {
  return CompanyOnMap(
    company: Company(composition: {UnitRole.warrior: 5}),
    id: id,
    ownership: ownership,
    currentNode: currentNode,
    destination: destination,
    progress: progress,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late GameMap map;
  late CheckCollisions useCase;

  // -----------------------------------------------------------------------
  // T003: CompanyOnMap.copyWith clears battleId when explicit null is passed
  // -----------------------------------------------------------------------

  group('CompanyOnMap.copyWith — battleId sentinel', () {
    test(
      'T003: battleId is preserved when copyWith is called without battleId arg',
      () {
        final co = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          battleId: 'battle_junction_mid',
        );
        final copied = co.copyWith(progress: 0.5);
        expect(copied.battleId, equals('battle_junction_mid'));
      },
    );

    test(
      'T003: battleId is cleared (null) when copyWith is called with explicit null',
      () {
        final co = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          battleId: 'battle_junction_mid',
        );
        // ignore: inference_failure_on_function_invocation
        final cleared = co.copyWith(battleId: null);
        expect(cleared.battleId, isNull);
      },
    );

    test(
      'T003: battleId defaults to null when not supplied to constructor',
      () {
        final co = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
        );
        expect(co.battleId, isNull);
      },
    );
  });

  setUp(() {
    map = _makeMap();
    useCase = const CheckCollisions();
  });

  group('CheckCollisions', () {
    group('empty map', () {
      test('empty companies list returns no triggers', () {
        final triggers = useCase.check(map: map, companies: []);
        expect(triggers, isEmpty);
      });
    });

    group('friendly Companies on same node', () {
      test('two friendly Companies on the same node return no trigger', () {
        final a = _makeCompany(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
        );
        final b = _makeCompany(
          id: 'p2',
          ownership: Ownership.player,
          currentNode: _junction,
        );
        final triggers = useCase.check(map: map, companies: [a, b]);
        expect(triggers, isEmpty);
      });
    });

    group('FR-014: opposing Companies on same road segment', () {
      test('player and AI Company on same node returns a road-collision trigger', () {
        final player = _makeCompany(
          id: 'player_co',
          ownership: Ownership.player,
          currentNode: _junction,
        );
        final ai = _makeCompany(
          id: 'ai_co',
          ownership: Ownership.ai,
          currentNode: _junction,
        );
        final triggers = useCase.check(map: map, companies: [player, ai]);
        expect(triggers, isNotEmpty);
        expect(
          triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
          isTrue,
        );
      });
    });

    group('FR-015: Company arriving at enemy castle node', () {
      test('player Company at AI castle returns a castle-assault trigger', () {
        final playerAtAiCastle = _makeCompany(
          id: 'player_co',
          ownership: Ownership.player,
          currentNode: _aiCastle,
        );
        final triggers = useCase.check(map: map, companies: [playerAtAiCastle]);
        expect(triggers, isNotEmpty);
        expect(
          triggers.any((t) => t.kind == BattleTriggerKind.castleAssault),
          isTrue,
        );
      });

      test('AI Company at player castle returns a castle-assault trigger', () {
        final aiAtPlayerCastle = _makeCompany(
          id: 'ai_co',
          ownership: Ownership.ai,
          currentNode: _playerCastle,
        );
        final triggers = useCase.check(map: map, companies: [aiAtPlayerCastle]);
        expect(triggers, isNotEmpty);
        expect(
          triggers.any((t) => t.kind == BattleTriggerKind.castleAssault),
          isTrue,
        );
      });

      test('friendly Company at own castle returns no trigger', () {
        final playerAtOwnCastle = _makeCompany(
          id: 'player_co',
          ownership: Ownership.player,
          currentNode: _playerCastle,
        );
        final triggers = useCase.check(
          map: map,
          companies: [playerAtOwnCastle],
        );
        expect(triggers, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // T049–T053: US4 — Friendly pass-through (Phase 6)
    // -----------------------------------------------------------------------

    group('T049: in-transit same-owner company at friendly-occupied node → no roadCollision', () {
      test(
        'player company in transit at node occupied only by stationary '
        'player company → no roadCollision',
        () {
          // Stationary player company at the junction.
          final stationary = _makeCompany(
            id: 'p_stationary',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: null,
          );
          // In-transit player company passing through the same junction.
          final inTransit = _makeCompany(
            id: 'p_transit',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );

          final triggers =
              useCase.check(map: map, companies: [stationary, inTransit]);

          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isFalse,
            reason: 'Same-owner pass-through must not trigger a roadCollision',
          );
        },
      );

      test(
        'two in-transit same-owner companies at same node → no roadCollision',
        () {
          final a = _makeCompany(
            id: 'p1',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );
          final b = _makeCompany(
            id: 'p2',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );

          final triggers = useCase.check(map: map, companies: [a, b]);

          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isFalse,
          );
        },
      );
    });

    group('T050: in-transit enemy company at player-occupied node → roadCollision', () {
      test(
        'AI company in transit at node with stationary player company '
        '→ roadCollision triggered',
        () {
          final playerStationary = _makeCompany(
            id: 'p_stationary',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: null,
          );
          final aiTransit = _makeCompany(
            id: 'ai_transit',
            ownership: Ownership.ai,
            currentNode: _junction,
            destination: _playerCastle,
          );

          final triggers = useCase.check(
            map: map,
            companies: [playerStationary, aiTransit],
          );

          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isTrue,
            reason:
                'Enemy in-transit company at player node must trigger roadCollision',
          );
        },
      );

      test(
        'AI company in transit at node with in-transit player company '
        '→ roadCollision triggered',
        () {
          final playerTransit = _makeCompany(
            id: 'p_transit',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );
          final aiTransit = _makeCompany(
            id: 'ai_transit',
            ownership: Ownership.ai,
            currentNode: _junction,
            destination: _playerCastle,
          );

          final triggers = useCase.check(
            map: map,
            companies: [playerTransit, aiTransit],
          );

          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isTrue,
            reason:
                'Opposing in-transit companies on same node must trigger roadCollision',
          );
        },
      );
    });

    group('T051: in-transit player company at enemy-occupied node → roadCollision', () {
      test(
        'player company in transit at node with stationary AI company '
        '→ roadCollision triggered',
        () {
          final aiStationary = _makeCompany(
            id: 'ai_stationary',
            ownership: Ownership.ai,
            currentNode: _junction,
            destination: null,
          );
          final playerTransit = _makeCompany(
            id: 'p_transit',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );

          final triggers = useCase.check(
            map: map,
            companies: [aiStationary, playerTransit],
          );

          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isTrue,
            reason:
                'Player in-transit company at enemy node must trigger roadCollision',
          );
        },
      );
    });

    group('T052: friendly pass-through does NOT displace or affect stationary company', () {
      test(
        'stationary player company at node is unchanged when friendly '
        'in-transit company passes through',
        () {
          final stationary = _makeCompany(
            id: 'p_stationary',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: null,
          );
          final inTransit = _makeCompany(
            id: 'p_transit',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );

          // check() is pure — it only returns triggers, never modifies input.
          // The test verifies there are no triggers that would indicate
          // an erroneous merge/displacement of the stationary company.
          final triggers =
              useCase.check(map: map, companies: [stationary, inTransit]);

          // No roadCollision — stationary company is not affected.
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isFalse,
          );
          // No castleAssault from a junction node.
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.castleAssault),
            isFalse,
          );
        },
      );
    });

    group('T053: stationary classification — null destination, destination == currentNode, '
        'destination ≠ currentNode', () {
      test(
        'company with null destination (stationary) sharing node only with '
        'same-owner in-transit company → no roadCollision',
        () {
          // destination == null → stationary
          final stationary = _makeCompany(
            id: 'p_stat',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: null,
          );
          final transit = _makeCompany(
            id: 'p_tran',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );
          final triggers =
              useCase.check(map: map, companies: [stationary, transit]);
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isFalse,
          );
        },
      );

      test(
        'company with destination == currentNode (treated as stationary) '
        'sharing node only with same-owner in-transit company → no roadCollision',
        () {
          // destination == currentNode → classified as stationary
          final stationaryAtNode = _makeCompany(
            id: 'p_stat',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _junction,
          );
          final transit = _makeCompany(
            id: 'p_tran',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );
          final triggers = useCase.check(
            map: map,
            companies: [stationaryAtNode, transit],
          );
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isFalse,
          );
        },
      );

      test(
        'company with destination ≠ currentNode (in transit) sharing node '
        'with enemy company → roadCollision regardless of transit state',
        () {
          // destination ≠ currentNode → in transit
          final playerTransit = _makeCompany(
            id: 'p_tran',
            ownership: Ownership.player,
            currentNode: _junction,
            destination: _aiCastle,
          );
          final aiStationary = _makeCompany(
            id: 'ai_stat',
            ownership: Ownership.ai,
            currentNode: _junction,
            destination: null,
          );
          final triggers = useCase.check(
            map: map,
            companies: [playerTransit, aiStationary],
          );
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isTrue,
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // T015: same-owner no trigger; 3+ opposing companies → ONE BattleTrigger
    // -----------------------------------------------------------------------

    group('T015: battle trigger grouping rules', () {
      test(
        'T015a: two same-owner companies at the same junction do NOT emit a battle trigger',
        () {
          final a = _makeCompany(
            id: 'p1',
            ownership: Ownership.player,
            currentNode: _junction,
          );
          final b = _makeCompany(
            id: 'p2',
            ownership: Ownership.player,
            currentNode: _junction,
          );
          final triggers = useCase.check(map: map, companies: [a, b]);
          expect(triggers, isEmpty,
              reason: 'Same-owner companies must never trigger a battle');
        },
      );

      test(
        'T015b: three opposing companies at the same junction produce exactly '
        'ONE BattleTrigger containing all company IDs',
        () {
          // Two player companies + one AI company at same junction
          final p1 = _makeCompany(
            id: 'p1',
            ownership: Ownership.player,
            currentNode: _junction,
          );
          final p2 = _makeCompany(
            id: 'p2',
            ownership: Ownership.player,
            currentNode: _junction,
          );
          final ai1 = _makeCompany(
            id: 'ai1',
            ownership: Ownership.ai,
            currentNode: _junction,
          );

          final triggers =
              useCase.check(map: map, companies: [p1, p2, ai1]);

          final roadTriggers = triggers
              .where((t) => t.kind == BattleTriggerKind.roadCollision)
              .toList();

          expect(roadTriggers, hasLength(1),
              reason: 'Must produce exactly ONE roadCollision trigger, not one per pair');

          final ids = roadTriggers.first.companyIds;
          expect(ids, containsAll(['p1', 'p2', 'ai1']),
              reason: 'Single trigger must contain all involved company IDs');
        },
      );

      test(
        'T015c: two AI and one player company at same junction → ONE trigger',
        () {
          final ai1 = _makeCompany(
            id: 'ai1',
            ownership: Ownership.ai,
            currentNode: _junction,
          );
          final ai2 = _makeCompany(
            id: 'ai2',
            ownership: Ownership.ai,
            currentNode: _junction,
          );
          final p1 = _makeCompany(
            id: 'p1',
            ownership: Ownership.player,
            currentNode: _junction,
          );

          final triggers =
              useCase.check(map: map, companies: [ai1, ai2, p1]);

          final roadTriggers = triggers
              .where((t) => t.kind == BattleTriggerKind.roadCollision)
              .toList();

          expect(roadTriggers, hasLength(1));
          expect(roadTriggers.first.companyIds, containsAll(['ai1', 'ai2', 'p1']));
        },
      );
    });
  });
}
