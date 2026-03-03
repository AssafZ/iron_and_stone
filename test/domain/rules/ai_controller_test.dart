// T081 — Failing unit tests for AiController
// Red-Green-Refactor: tests FAIL before AiController exists, then GREEN after.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/ai_controller.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GameMap _makeMinimalMap() {
  const playerCastle = CastleNode(
    id: 'pc',
    x: 0.0,
    y: 0.0,
    ownership: Ownership.player,
  );
  const aiCastle = CastleNode(
    id: 'ac',
    x: 200.0,
    y: 0.0,
    ownership: Ownership.ai,
  );
  return GameMap(
    nodes: [playerCastle, aiCastle],
    edges: [
      RoadEdge(from: playerCastle, to: aiCastle, length: 200.0),
      RoadEdge(from: aiCastle, to: playerCastle, length: 200.0),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AiController', () {
    // -------------------------------------------------------------------------
    // No garrison-based deploy — AI starts with a company
    // -------------------------------------------------------------------------
    group('decide — no deploy from garrison', () {
      test(
          'returns NoAction (not DeployAction) even when AI castle garrison has units',
          () {
        // Garrison is unused — AI does not deploy from it.
        final map = _makeMinimalMap();
        final aiCastleNode = map.nodes
            .whereType<CastleNode>()
            .firstWhere((n) => n.ownership == Ownership.ai);
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {UnitRole.warrior: 10},
        );
        final playerCastle = Castle(
          id: 'pc',
          ownership: Ownership.player,
          garrison: {},
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [],
        );

        // With no stationary AI company, no move order — NoAction.
        expect(action, isA<NoAction>());
      });

      test(
          'returns MoveAction (not DeployAction) when AI has a stationary company and garrison has units',
          () {
        final map = _makeMinimalMap();
        final aiCastleNode = map.nodes
            .whereType<CastleNode>()
            .firstWhere((n) => n.ownership == Ownership.ai);
        final playerCastleNode = map.nodes
            .whereType<CastleNode>()
            .firstWhere((n) => n.ownership == Ownership.player);
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {UnitRole.warrior: 15, UnitRole.archer: 5},
        );
        final playerCastle = Castle(
          id: 'pc',
          ownership: Ownership.player,
          garrison: {},
        );
        final aiCompany = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: 'ai_co0',
          ownership: Ownership.ai,
          currentNode: aiCastleNode,
          destination: null,
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [aiCompany],
        );

        // Move action, not deploy.
        expect(action, isA<MoveAction>());
        final move = action as MoveAction;
        expect(move.destination.id, equals(playerCastleNode.id));
      });

      test('decide never returns a DeployAction', () {
        final map = _makeMinimalMap();
        final aiCastleNode = map.nodes
            .whereType<CastleNode>()
            .firstWhere((n) => n.ownership == Ownership.ai);
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {
            UnitRole.warrior: 100,
            UnitRole.archer: 100,
          },
        );
        final playerCastle = Castle(
          id: 'pc',
          ownership: Ownership.player,
          garrison: {},
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [],
        );
        expect(action, isNot(isA<DeployAction>()));
      });
    });

    // -------------------------------------------------------------------------
    // move action
    // -------------------------------------------------------------------------
    group('decide — move action', () {
      test(
          'returns MoveAction targeting nearest non-AI castle when AI has a stationary Company',
          () {
        final map = _makeMinimalMap();
        final aiCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.ai,
            );
        final playerCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.player,
            );
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {},
        );
        final playerCastle = Castle(
          id: 'pc',
          ownership: Ownership.player,
          garrison: {},
        );

        final aiCompany = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: 'ai_co1',
          ownership: Ownership.ai,
          currentNode: aiCastleNode,
          destination: null,
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [aiCompany],
        );

        expect(action, isA<MoveAction>());
        final move = action as MoveAction;
        expect(move.companyId, equals('ai_co1'));
        expect(move.destination.id, equals(playerCastleNode.id));
      });

      test('MoveAction destination is a non-AI castle node', () {
        final map = GameMapFixture.build();
        final aiCastleNode = map.nodes
            .whereType<CastleNode>()
            .firstWhere((n) => n.ownership == Ownership.ai);
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {},
        );
        final playerCastle = Castle(
          id: GameMapFixture.playerCastleId,
          ownership: Ownership.player,
          garrison: {},
        );
        final aiCompany = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 10}),
          id: 'ai_co1',
          ownership: Ownership.ai,
          currentNode: aiCastleNode,
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [aiCompany],
        );
        expect(action, isA<MoveAction>());
        final move = action as MoveAction;
        final targetNode =
            map.nodes.firstWhere((n) => n.id == move.destination.id);
        expect(targetNode, isA<CastleNode>());
        final castle = targetNode as CastleNode;
        expect(castle.ownership, isNot(Ownership.ai));
      });
    });

    // -------------------------------------------------------------------------
    // no action
    // -------------------------------------------------------------------------
    group('decide — no action', () {
      test(
          'returns NoAction when AI garrison is empty and no companies on map',
          () {
        final map = _makeMinimalMap();
        final aiCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.ai,
            );
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {},
        );
        final playerCastle = Castle(
          id: 'pc',
          ownership: Ownership.player,
          garrison: {},
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [],
        );
        expect(action, isA<NoAction>());
      });

      test(
          'returns NoAction when AI garrison has < 10 units and no companies',
          () {
        final map = _makeMinimalMap();
        final aiCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.ai,
            );
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {UnitRole.warrior: 5},
        );
        final playerCastle = Castle(
          id: 'pc',
          ownership: Ownership.player,
          garrison: {},
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [],
        );
        expect(action, isA<NoAction>());
      });

      test(
          'returns MoveAction (not NoAction) when a stationary company exists even if garrison is empty',
          () {
        final map = _makeMinimalMap();
        final aiCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.ai,
            );
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {},
        );
        final playerCastle = Castle(
          id: 'pc',
          ownership: Ownership.player,
          garrison: {},
        );
        final aiCompany = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: 'ai_co1',
          ownership: Ownership.ai,
          currentNode: aiCastleNode,
          destination: null,
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [aiCompany],
        );
        expect(action, isA<MoveAction>());
      });

      test(
          'returns NoAction when all AI companies already have a destination',
          () {
        final map = _makeMinimalMap();
        final aiCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.ai,
            );
        final playerCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.player,
            );
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {},
        );
        final playerCastle = Castle(
          id: 'pc',
          ownership: Ownership.player,
          garrison: {},
        );
        final aiCompany = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: 'ai_co1',
          ownership: Ownership.ai,
          currentNode: aiCastleNode,
          destination: playerCastleNode,
        );

        final action = const AiController().decide(
          map: map,
          castles: [playerCastle, aiCastle],
          companies: [aiCompany],
        );
        expect(action, isA<NoAction>());
      });
    });

    // -------------------------------------------------------------------------
    // Pure Dart — no Flutter dependency
    // -------------------------------------------------------------------------
    test('AiController is a pure Dart class (no Flutter binding required)',
        () {
      final map = _makeMinimalMap();
      final aiCastleNode =
          map.nodes.whereType<CastleNode>().firstWhere(
            (n) => n.ownership == Ownership.ai,
          );
      expect(
        () => const AiController().decide(
          map: map,
          castles: [
            Castle(id: aiCastleNode.id, ownership: Ownership.ai, garrison: {}),
            Castle(id: 'pc', ownership: Ownership.player, garrison: {}),
          ],
          companies: [],
        ),
        returnsNormally,
      );
    });
  });
}
