import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/victory_checker.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/tick_match.dart';
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
  group('TickMatch', () {
    group('castle growth', () {
      test('single tick increases garrison count for a castle below cap', () {
        final map = _makeMinimalMap();
        final castleNode = map.nodes.whereType<CastleNode>().first;
        final castle = Castle(
          id: castleNode.id,
          ownership: castleNode.ownership,
          garrison: {UnitRole.warrior: 0},
        );
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final useCase = const TickMatch();
        final result = useCase.tick(
          match: match,
          castles: [castle],
          companies: [],
        );

        final updatedCastle = result.castles.firstWhere((c) => c.id == castle.id);
        // Growth engine should have added at least 1 warrior
        expect(
          updatedCastle.garrison[UnitRole.warrior] ?? 0,
          greaterThan(0),
        );
      });
    });

    group('company position advance', () {
      test('single tick moves a company forward along its path', () {
        final map = GameMapFixture.build();
        final playerCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.player,
            );
        final junction = map.nodes.whereType<RoadJunctionNode>().first;
        final company = CompanyOnMap(
          company: Company(composition: {UnitRole.warrior: 5}),
          id: 'co_1',
          ownership: Ownership.player,
          currentNode: playerCastleNode,
          destination: junction,
          progress: 0.0,
        );

        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final useCase = const TickMatch();
        final result = useCase.tick(
          match: match,
          castles: [],
          companies: [company],
        );

        final updated = result.companies.first;
        // Progress should have advanced (> 0 or moved to next node)
        expect(
          updated.progress > 0.0 || updated.currentNode.id != playerCastleNode.id,
          isTrue,
        );
      });
    });

    group('CheckCollisions called', () {
      test('TickResult contains battleTriggers field (may be empty)', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final useCase = const TickMatch();
        final result = useCase.tick(
          match: match,
          castles: [],
          companies: [],
        );

        expect(result.battleTriggers, isA<List<BattleTrigger>>());
      });
    });

    group('TickResult shape', () {
      test('TickResult contains updated castles', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final useCase = const TickMatch();
        final result = useCase.tick(
          match: match,
          castles: [],
          companies: [],
        );

        expect(result.castles, isA<List<Castle>>());
      });

      test('TickResult contains updated companies list', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final useCase = const TickMatch();
        final result = useCase.tick(
          match: match,
          castles: [],
          companies: [],
        );

        expect(result.companies, isA<List<CompanyOnMap>>());
      });

      test('TickResult matchOutcome is null when no castles are player-only', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );
        final castles = map.nodes.whereType<CastleNode>().map((n) {
          return Castle(
            id: n.id,
            ownership: n.ownership, // mixed: player + ai
            garrison: {},
          );
        }).toList();

        final useCase = const TickMatch();
        final result = useCase.tick(
          match: match,
          castles: castles,
          companies: [],
        );

        expect(result.matchOutcome, isNull);
      });

      test('TickResult matchOutcome is playerWins when all castles are player-owned', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );
        final castles = map.nodes.whereType<CastleNode>().map((n) {
          return Castle(
            id: n.id,
            ownership: Ownership.player, // all player
            garrison: {},
          );
        }).toList();

        final useCase = const TickMatch();
        final result = useCase.tick(
          match: match,
          castles: castles,
          companies: [],
        );

        expect(result.matchOutcome, equals(MatchOutcome.playerWins));
      });
    });

    // -------------------------------------------------------------------------
    // T067 — TickMatch delegates to TickCastleGrowth
    // -------------------------------------------------------------------------

    group('TickCastleGrowth integration (T067)', () {
      test('castle garrison increases after one tick when below cap', () {
        final map = _makeMinimalMap();
        final castleNode =
            map.nodes.whereType<CastleNode>().first;
        final castle = Castle(
          id: castleNode.id,
          ownership: castleNode.ownership,
          garrison: {UnitRole.warrior: 0},
        );
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final result = const TickMatch().tick(
          match: match,
          castles: [castle],
          companies: [],
        );

        final updated = result.castles.firstWhere((c) => c.id == castle.id);
        // Growth engine should have added at least 1 warrior.
        expect(updated.garrison[UnitRole.warrior] ?? 0, greaterThan(0));
      });

      test('TickCastleGrowth halt respected: garrison at cap produces no change', () {
        final map = _makeMinimalMap();
        final castleNode = map.nodes.whereType<CastleNode>().first;
        // Fill to 250 (base cap).
        final garrison = {
          for (final role in UnitRole.values) role: 50,
        };
        final castle = Castle(
          id: castleNode.id,
          ownership: castleNode.ownership,
          garrison: garrison,
        );
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final result = const TickMatch().tick(
          match: match,
          castles: [castle],
          companies: [],
        );

        final updated = result.castles.firstWhere((c) => c.id == castle.id);
        final totalAfter = updated.garrison.values.fold(0, (s, v) => s + v);
        expect(totalAfter, equals(250));
      });

      test('all castles are grown each tick', () {
        final map = GameMapFixture.build();
        final castles = map.nodes.whereType<CastleNode>().map((n) {
          return Castle(
            id: n.id,
            ownership: n.ownership,
            garrison: {UnitRole.warrior: 0},
          );
        }).toList();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final result = const TickMatch().tick(
          match: match,
          castles: castles,
          companies: [],
        );

        expect(result.castles.length, equals(castles.length));
        for (final updated in result.castles) {
          expect(updated.garrison[UnitRole.warrior] ?? 0, greaterThan(0));
        }
      });
    });

    // -------------------------------------------------------------------------
    // T085 — AiController integration
    // -------------------------------------------------------------------------

    group('AiController integration (T085)', () {
      test(
          'TickResult.companies contains an AI Company after first tick when AI garrison >= 10',
          () {
        final map = GameMapFixture.build();
        final aiCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.ai,
            );
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {UnitRole.warrior: 20, UnitRole.archer: 10},
        );
        final playerCastle = Castle(
          id: GameMapFixture.playerCastleId,
          ownership: Ownership.player,
          garrison: {},
        );
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final result = const TickMatch().tick(
          match: match,
          castles: [playerCastle, aiCastle],
          companies: [],
        );

        final aiCompanies = result.companies
            .where((c) => c.ownership == Ownership.ai)
            .toList();

        expect(
          aiCompanies.length,
          greaterThanOrEqualTo(1),
          reason:
              'TickResult must include an AI Company after tick with garrison >= 10',
        );
      });

      test(
          'AI Company is not deployed when garrison < 10 units',
          () {
        final map = GameMapFixture.build();
        final aiCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.ai,
            );
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {UnitRole.warrior: 3}, // below threshold
        );
        final playerCastle = Castle(
          id: GameMapFixture.playerCastleId,
          ownership: Ownership.player,
          garrison: {},
        );
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final result = const TickMatch().tick(
          match: match,
          castles: [playerCastle, aiCastle],
          companies: [],
        );

        final aiCompanies = result.companies
            .where((c) => c.ownership == Ownership.ai)
            .toList();

        expect(
          aiCompanies,
          isEmpty,
          reason: 'AI should not deploy when garrison < 10 units',
        );
      });

      test('AI Company receives destination (MoveAction) after deploy tick',
          () {
        final map = GameMapFixture.build();
        final aiCastleNode =
            map.nodes.whereType<CastleNode>().firstWhere(
              (n) => n.ownership == Ownership.ai,
            );
        final aiCastle = Castle(
          id: aiCastleNode.id,
          ownership: Ownership.ai,
          garrison: {UnitRole.warrior: 20},
        );
        final playerCastle = Castle(
          id: GameMapFixture.playerCastleId,
          ownership: Ownership.player,
          garrison: {},
        );
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        // Tick 1: deploy
        final tick1 = const TickMatch().tick(
          match: match,
          castles: [playerCastle, aiCastle],
          companies: [],
        );

        // Tick 2: move (company is stationary, should get a destination)
        final tick2 = const TickMatch().tick(
          match: match,
          castles: tick1.castles,
          companies: tick1.companies,
        );

        final aiCompanies = tick2.companies
            .where((c) => c.ownership == Ownership.ai)
            .toList();

        expect(aiCompanies, isNotEmpty);
        // After second tick, the AI company should have a destination assigned.
        final hasDestination = aiCompanies.any((c) => c.destination != null);
        expect(
          hasDestination,
          isTrue,
          reason: 'AI Company must receive a destination on the tick after deploy',
        );
      });
    });

    // -------------------------------------------------------------------------
    // T090 — VictoryChecker delegation
    // -------------------------------------------------------------------------

    group('VictoryChecker delegation (T090)', () {
      test(
          'TickResult.matchOutcome == MatchOutcome.playerWins when all castles are player-owned',
          () {
        final map = GameMapFixture.build();
        final allPlayerCastles = map.nodes
            .whereType<CastleNode>()
            .map(
              (n) => Castle(
                id: n.id,
                ownership: Ownership.player,
                garrison: {},
              ),
            )
            .toList();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final result = const TickMatch().tick(
          match: match,
          castles: allPlayerCastles,
          companies: [],
        );

        // TickMatch delegates to VictoryChecker; both must agree.
        final checkerOutcome = const VictoryChecker().check(allPlayerCastles);
        expect(result.matchOutcome, equals(MatchOutcome.playerWins));
        expect(result.matchOutcome, equals(checkerOutcome));
      });

      test(
          'TickResult.matchOutcome == MatchOutcome.aiWins when all castles are AI-owned',
          () {
        final map = GameMapFixture.build();
        final allAiCastles = map.nodes
            .whereType<CastleNode>()
            .map(
              (n) => Castle(
                id: n.id,
                ownership: Ownership.ai,
                garrison: {},
              ),
            )
            .toList();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final result = const TickMatch().tick(
          match: match,
          castles: allAiCastles,
          companies: [],
        );

        final checkerOutcome = const VictoryChecker().check(allAiCastles);
        expect(result.matchOutcome, equals(MatchOutcome.aiWins));
        expect(result.matchOutcome, equals(checkerOutcome));
      });

      test(
          'TickResult.matchOutcome is null when castles have mixed ownership',
          () {
        final map = _makeMinimalMap();
        // Default fixture: player + ai owned castles.
        final mixedCastles = map.nodes
            .whereType<CastleNode>()
            .map(
              (n) => Castle(
                id: n.id,
                ownership: n.ownership,
                garrison: {},
              ),
            )
            .toList();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );

        final result = const TickMatch().tick(
          match: match,
          castles: mixedCastles,
          companies: [],
        );

        final checkerOutcome = const VictoryChecker().check(mixedCastles);
        expect(result.matchOutcome, isNull);
        expect(result.matchOutcome, equals(checkerOutcome));
      });
    });
  });
}
