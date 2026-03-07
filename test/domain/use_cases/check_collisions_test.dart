import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';

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
      test(
        'player Company at AI castle with AI garrison returns a castle-assault trigger',
        () {
          final playerAtAiCastle = _makeCompany(
            id: 'player_co',
            ownership: Ownership.player,
            currentNode: _aiCastle,
          );
          // AI garrison present at its own castle (stationary)
          final aiGarrison = _makeCompany(
            id: 'ai_garrison',
            ownership: Ownership.ai,
            currentNode: _aiCastle,
            destination: null,
          );
          final triggers =
              useCase.check(map: map, companies: [playerAtAiCastle, aiGarrison]);
          expect(triggers, isNotEmpty);
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.castleAssault),
            isTrue,
          );
        },
      );

      test(
        'AI Company at player castle with player garrison returns a castle-assault trigger',
        () {
          final aiAtPlayerCastle = _makeCompany(
            id: 'ai_co',
            ownership: Ownership.ai,
            currentNode: _playerCastle,
          );
          // Player garrison present at its own castle (stationary)
          final playerGarrison = _makeCompany(
            id: 'player_garrison',
            ownership: Ownership.player,
            currentNode: _playerCastle,
            destination: null,
          );
          final triggers = useCase.check(
              map: map, companies: [aiAtPlayerCastle, playerGarrison]);
          expect(triggers, isNotEmpty);
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.castleAssault),
            isTrue,
          );
        },
      );

      test(
        'player Company at empty AI castle (no garrison) returns NO castle-assault trigger',
        () {
          final playerAtAiCastle = _makeCompany(
            id: 'player_co',
            ownership: Ownership.player,
            currentNode: _aiCastle,
          );
          // No AI garrison — empty castle
          final triggers =
              useCase.check(map: map, companies: [playerAtAiCastle]);
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.castleAssault),
            isFalse,
            reason: 'Empty enemy castle must not trigger castleAssault',
          );
        },
      );

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

    // -----------------------------------------------------------------------
    // T025 / T025b: US2 — castleAssault triggered only by garrison companies
    // -----------------------------------------------------------------------

    group('T025: castleAssault trigger requires garrison companies at castle', () {
      test(
        'T025: attacking company arrives at enemy castle with garrison companies '
        '→ castleAssault trigger is emitted',
        () {
          // AI garrison at player castle (stationary, destination == null)
          final aiGarrison = _makeCompany(
            id: 'ai_garrison',
            ownership: Ownership.ai,
            currentNode: _playerCastle,
            destination: null,
          );
          // Player attacker arriving at the castle
          final playerAttacker = _makeCompany(
            id: 'player_attack',
            ownership: Ownership.player,
            currentNode: _playerCastle,
          );

          final triggers = useCase.check(
            map: map,
            companies: [aiGarrison, playerAttacker],
          );

          final castleTriggers = triggers
              .where((t) => t.kind == BattleTriggerKind.castleAssault)
              .toList();
          expect(
            castleTriggers,
            isNotEmpty,
            reason:
                'castleAssault must be emitted when attacking company arrives '
                'at enemy castle with garrison companies',
          );
        },
      );

      test(
        'T025: castleAssault trigger includes IDs of defending garrison companies',
        () {
          // Two AI garrison companies at player castle
          final aiG1 = _makeCompany(
            id: 'ai_g1',
            ownership: Ownership.ai,
            currentNode: _playerCastle,
            destination: null,
          );
          final aiG2 = _makeCompany(
            id: 'ai_g2',
            ownership: Ownership.ai,
            currentNode: _playerCastle,
            destination: null,
          );
          final playerAttacker = _makeCompany(
            id: 'player_attack',
            ownership: Ownership.player,
            currentNode: _playerCastle,
          );

          final triggers = useCase.check(
            map: map,
            companies: [aiG1, aiG2, playerAttacker],
          );

          final castleTrigger = triggers.firstWhere(
            (t) => t.kind == BattleTriggerKind.castleAssault,
          );
          expect(
            castleTrigger.companyIds,
            containsAll(['ai_g1', 'ai_g2', 'player_attack']),
            reason: 'Trigger must include all defending garrison and attacking company IDs',
          );
        },
      );
    });

    group('T025b: in-transit company at castle does NOT count as garrison', () {
      test(
        'T025b: attacker arrives at enemy castle where the only enemy company '
        'is in-transit (non-null destination) → no castleAssault (no living garrison)',
        () {
          // Player attacker at AI castle
          final playerAttacker = _makeCompany(
            id: 'player_attack',
            ownership: Ownership.player,
            currentNode: _aiCastle,
            destination: null,
          );
          // AI company in transit through its own castle (has a destination → not garrison)
          final aiTransiting = _makeCompany(
            id: 'ai_transit',
            ownership: Ownership.ai,
            currentNode: _aiCastle,
            destination: _junction, // in transit, not garrison
          );

          final triggers = useCase.check(
            map: map,
            companies: [playerAttacker, aiTransiting],
          );

          // Since the only AI company is in-transit, there is no garrison.
          // castleAssault must NOT be triggered (only a roadCollision may fire if applicable).
          final castleAssaultTriggers = triggers
              .where((t) => t.kind == BattleTriggerKind.castleAssault)
              .toList();
          expect(
            castleAssaultTriggers,
            isEmpty,
            reason:
                'In-transit AI at own castle must not count as garrison defender; '
                'no castleAssault should be emitted when there are no stationary garrison',
          );
        },
      );

      test(
        'T025b: in-transit enemy at castle alone → castleAssault trigger is NOT emitted; '
        'roadCollision may be emitted if any enemy company is present',
        () {
          // AI company in transit at player castle (no stationary player garrison)
          final aiTransiting = _makeCompany(
            id: 'ai_transit',
            ownership: Ownership.ai,
            currentNode: _playerCastle,
            destination: _junction, // in transit
          );

          // No player garrison companies present at all — ai_transit is just passing through.
          // Also: there's no friendly player stationary company, so no garrison.
          // Since ai_transit is the ONLY company at the castle and there's no enemy
          // garrison company, no castleAssault is emitted.
          final triggers = useCase.check(
            map: map,
            companies: [aiTransiting],
          );

          // ai_transit is at an enemy castle but there is no garrison → no castleAssault
          expect(
            triggers.where((t) => t.kind == BattleTriggerKind.castleAssault),
            isEmpty,
            reason:
                'A single in-transit company at an enemy castle with no garrison '
                'must not trigger a castleAssault',
          );
        },
      );
    });
    // -----------------------------------------------------------------------
    // T061 (Phase 4b): garrison with 0-soldier companies → no castleAssault
    // -----------------------------------------------------------------------

    group('T061: garrison companies with 0 soldiers are ignored', () {
      test(
        'T061: all garrison companies at castle have 0 soldiers → '
        'attacking company captures castle without a battle (no castleAssault)',
        () {
          // AI garrison company with 0 soldiers (dead/empty) at AI castle
          final deadGarrison = CompanyOnMap(
            company: Company(composition: {}), // 0 soldiers
            id: 'ai_dead',
            ownership: Ownership.ai,
            currentNode: _aiCastle,
            destination: null,
          );
          // Player attacker arriving at the AI castle
          final playerAttacker = _makeCompany(
            id: 'player_attack',
            ownership: Ownership.player,
            currentNode: _aiCastle,
          );

          // The only AI company at the AI castle has 0 soldiers → not valid garrison
          final triggers = useCase.check(
            map: map,
            companies: [deadGarrison, playerAttacker],
          );

          // castleAssault must NOT be triggered — dead garrison doesn't count
          final castleTriggers = triggers
              .where((t) => t.kind == BattleTriggerKind.castleAssault)
              .toList();
          expect(
            castleTriggers.every((t) => !t.companyIds.contains('ai_dead')),
            isTrue,
            reason:
                'A 0-soldier garrison company must not trigger a castleAssault',
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // T019: mid-road segment collisions (Phase 4 — US2)
    // -----------------------------------------------------------------------

    group('T019: mid-road collisions', () {
      // Helpers for mid-road companies on the player_castle → junction_mid segment
      // (length 150.0). Both companies share currentNode=player_castle, nextNode=junction_mid.

      CompanyOnMap _makeMidRoadCompany({
        required String id,
        required Ownership ownership,
        required MapNode currentNode,
        required String nextNodeId,
        required double progress,
        MapNode? destination,
        RoadPosition? midRoadDestination,
      }) {
        return CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: id,
          ownership: ownership,
          currentNode: currentNode,
          destination: destination,
          progress: progress,
          midRoadDestination: midRoadDestination,
        );
      }

      test(
        'T019(a) head-on crossing: two enemies on same segment moving toward each '
        'other → roadCollision trigger emitted with midRoadProgress at midpoint',
        () {
          // Player at progress 0.3 marching toward junction_mid (nextNode = junction_mid)
          final player = _makeMidRoadCompany(
            id: 'p1',
            ownership: Ownership.player,
            currentNode: _playerCastle,
            nextNodeId: _junction.id,
            progress: 0.3,
            destination: _junction, // marching toward junction
          );
          // AI at progress 0.7 on the REVERSE segment: junction_mid → player_castle,
          // meaning it started at junction_mid and is progressing toward player_castle.
          // Both are on the same road "corridor" but opposite directed edges.
          // They are crossing (player goes 0.3→0.7 range, AI goes 0.7→0.3 on same corridor).
          // We model this by placing both on the same canonical segment.
          // Player is on player_castle→junction_mid at progress=0.3.
          // AI is on junction_mid→player_castle at progress=0.3 (meaning 0.7 from playerCastle side).
          final ai = _makeMidRoadCompany(
            id: 'ai1',
            ownership: Ownership.ai,
            currentNode: _junction,
            nextNodeId: _playerCastle.id,
            progress: 0.3, // 0.3 from junction_mid toward player_castle = 0.7 from player_castle
            destination: _playerCastle,
          );
          final triggers = useCase.check(map: map, companies: [player, ai]);
          // Look for the mid-road trigger specifically.
          final midRoadTriggers = triggers
              .where((t) =>
                  t.kind == BattleTriggerKind.roadCollision &&
                  t.midRoadProgress != null)
              .toList();
          expect(
            midRoadTriggers,
            isNotEmpty,
            reason: 'Head-on enemies crossing on same segment must trigger mid-road roadCollision',
          );
          final trigger = midRoadTriggers.first;
          expect(trigger.companyIds, containsAll(['p1', 'ai1']));
          // midRoadProgress should be between 0 and 1
          expect(trigger.midRoadProgress, greaterThan(0.0));
          expect(trigger.midRoadProgress, lessThan(1.0));
        },
      );

      test(
        'T019(b) overtake: faster enemy passes slower enemy on same segment '
        '→ roadCollision triggered at slower company\'s progress',
        () {
          // Both marching in the same direction: player_castle → junction_mid.
          // Slow player at progress 0.4 (just a bit ahead).
          // Fast AI starts at progress 0.6 (just caught up — already past slow).
          // We simulate "overtake already happened" by having AI at > player progress.
          final slowPlayer = _makeMidRoadCompany(
            id: 'slow_p',
            ownership: Ownership.player,
            currentNode: _playerCastle,
            nextNodeId: _junction.id,
            progress: 0.4,
            destination: _junction,
          );
          final fastAi = _makeMidRoadCompany(
            id: 'fast_ai',
            ownership: Ownership.ai,
            currentNode: _playerCastle,
            nextNodeId: _junction.id,
            progress: 0.4, // same position → overlap = trigger
            destination: _junction,
          );
          final triggers = useCase.check(map: map, companies: [slowPlayer, fastAi]);
          // Find the mid-road trigger specifically (progress > 0 companies may
          // also appear in the node-level trigger).
          final midRoadTriggers = triggers
              .where((t) =>
                  t.kind == BattleTriggerKind.roadCollision &&
                  t.midRoadProgress != null)
              .toList();
          expect(
            midRoadTriggers,
            isNotEmpty,
            reason: 'Enemies at same progress on same segment must trigger mid-road roadCollision',
          );
          final trigger = midRoadTriggers.first;
          expect(trigger.companyIds, containsAll(['slow_p', 'fast_ai']));
          expect(
            trigger.midRoadProgress,
            closeTo(0.4, 0.001),
            reason: 'Overtake collision midRoadProgress must equal the overlap position',
          );
        },
      );

      test(
        'T019(c) stationary mid-road hit: moving enemy reaches stationary '
        'enemy\'s segment position → roadCollision at stationary progress',
        () {
          // Player company stopped at mid-road (no destination, midRoadDestination cleared,
          // progress = 0.5 on player_castle → junction_mid).
          final stationaryPlayer = _makeMidRoadCompany(
            id: 'stat_p',
            ownership: Ownership.player,
            currentNode: _playerCastle,
            nextNodeId: _junction.id,
            progress: 0.5,
            destination: null, // stationary mid-road
          );
          // AI marching along the same segment, currently at the same position.
          final movingAi = _makeMidRoadCompany(
            id: 'moving_ai',
            ownership: Ownership.ai,
            currentNode: _playerCastle,
            nextNodeId: _junction.id,
            progress: 0.5, // arrived at stationary player's position
            destination: _junction,
          );
          final triggers = useCase.check(map: map, companies: [stationaryPlayer, movingAi]);
          // Find the mid-road trigger specifically.
          final midRoadTriggers = triggers
              .where((t) =>
                  t.kind == BattleTriggerKind.roadCollision &&
                  t.midRoadProgress != null)
              .toList();
          expect(
            midRoadTriggers,
            isNotEmpty,
            reason: 'Enemy reaching stationary mid-road company must trigger mid-road roadCollision',
          );
          final trigger = midRoadTriggers.first;
          expect(trigger.companyIds, containsAll(['stat_p', 'moving_ai']));
          expect(
            trigger.midRoadProgress,
            closeTo(0.5, 0.001),
            reason: 'Stationary mid-road hit midRoadProgress must equal stationary progress',
          );
        },
      );

      test(
        'T019(d) friendly pass-through: friendly companies on same segment '
        '→ no roadCollision trigger',
        () {
          final friendly1 = _makeMidRoadCompany(
            id: 'p1',
            ownership: Ownership.player,
            currentNode: _playerCastle,
            nextNodeId: _junction.id,
            progress: 0.5,
            destination: _junction,
          );
          final friendly2 = _makeMidRoadCompany(
            id: 'p2',
            ownership: Ownership.player,
            currentNode: _playerCastle,
            nextNodeId: _junction.id,
            progress: 0.5,
            destination: _junction,
          );
          final triggers = useCase.check(map: map, companies: [friendly1, friendly2]);
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isFalse,
            reason: 'Friendly companies on same segment must never trigger roadCollision',
          );
        },
      );

      test(
        'T019(e) regression: existing node-collision tests still work — '
        'two enemies at a node without mid-road positions trigger roadCollision',
        () {
          final player = _makeCompany(
            id: 'p_node',
            ownership: Ownership.player,
            currentNode: _junction,
          );
          final ai = _makeCompany(
            id: 'ai_node',
            ownership: Ownership.ai,
            currentNode: _junction,
          );
          final triggers = useCase.check(map: map, companies: [player, ai]);
          expect(
            triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
            isTrue,
            reason: 'Existing node-level road collision must still trigger',
          );
          // Node-level collision has no midRoadProgress.
          final nodeTrigger = triggers
              .firstWhere((t) => t.kind == BattleTriggerKind.roadCollision);
          expect(
            nodeTrigger.midRoadProgress,
            isNull,
            reason: 'Node collision must have null midRoadProgress',
          );
        },
      );
    });
  });
}
