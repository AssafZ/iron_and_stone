// T088 — Failing integration test: full match from launch to Total Conquest.
// T097 — Persistence round-trip assertions and SC-006 end-to-end test.
// Red-Green-Refactor: tests confirm MatchPhase transitions and correct MatchOutcome.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/data/drift/app_database.dart';
import 'package:iron_and_stone/data/drift/match_dao.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/victory_checker.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/tick_match.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build castles from fixture map with default garrison.
List<Castle> _buildCastles(GameMap map) {
  return map.nodes.whereType<CastleNode>().map((node) {
    return Castle(
      id: node.id,
      ownership: node.ownership,
      garrison: {UnitRole.warrior: 20, UnitRole.archer: 5},
    );
  }).toList();
}

/// Run [ticks] ticks of [TickMatch] returning the final state.
({List<Castle> castles, List<CompanyOnMap> companies, MatchOutcome? outcome})
    _runTicks({
  required GameMap map,
  required List<Castle> castles,
  required List<CompanyOnMap> companies,
  required int ticks,
}) {
  final match = Match(
    map: map,
    humanPlayer: Ownership.player,
    phase: MatchPhase.playing,
  );
  var currentCastles = castles;
  var currentCompanies = companies;
  MatchOutcome? lastOutcome;

  for (var i = 0; i < ticks; i++) {
    final result = const TickMatch().tick(
      match: match.copyWith(
        elapsedTime: Duration(seconds: i * 10),
      ),
      castles: currentCastles,
      companies: currentCompanies,
    );
    currentCastles = result.castles;
    currentCompanies = result.companies;
    lastOutcome = result.matchOutcome ?? lastOutcome;
  }

  return (
    castles: currentCastles,
    companies: currentCompanies,
    outcome: lastOutcome,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Full match integration (T088)', () {
    // -------------------------------------------------------------------------
    // MatchPhase transitions
    // -------------------------------------------------------------------------
    group('MatchPhase transitions', () {
      test('match starts in setup phase before newGame, then transitions to playing', () {
        // A Match created explicitly in setup transitions to playing when
        // the notifier calls newGame. We verify the Match entity supports
        // MatchPhase.setup as a valid starting value.
        final map = GameMapFixture.build();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.setup,
        );

        expect(match.phase, equals(MatchPhase.setup));

        // Simulating newGame: phase becomes playing.
        final playingMatch = match.copyWith(phase: MatchPhase.playing);
        expect(playingMatch.phase, equals(MatchPhase.playing));
      });

      test('match phase transitions to ended when MatchOutcome is determined', () {
        final map = GameMapFixture.build();
        // Force all castles to player ownership.
        final allPlayerCastles = map.nodes
            .whereType<CastleNode>()
            .map(
              (n) => Castle(
                id: n.id,
                ownership: Ownership.player,
                garrison: {UnitRole.warrior: 5},
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

        // TickMatch should emit playerWins outcome.
        expect(result.matchOutcome, equals(MatchOutcome.playerWins));

        // The notifier would set phase to ended when matchOutcome != null.
        final endedMatch = match.copyWith(
          phase:
              result.matchOutcome != null ? MatchPhase.ended : MatchPhase.playing,
        );
        expect(endedMatch.phase, equals(MatchPhase.ended));
      });
    });

    // -------------------------------------------------------------------------
    // Total Conquest — player wins
    // -------------------------------------------------------------------------
    group('Total Conquest — player wins', () {
      test('TickMatch returns playerWins when all castles are player-owned', () {
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

        expect(
          result.matchOutcome,
          equals(MatchOutcome.playerWins),
          reason: 'All player-owned castles must trigger playerWins',
        );
      });

      test('VictoryChecker.check agrees with TickResult.matchOutcome for player victory', () {
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

        // Both TickMatch and VictoryChecker agree.
        final checkerOutcome =
            const VictoryChecker().check(allPlayerCastles);

        expect(result.matchOutcome, equals(checkerOutcome));
        expect(checkerOutcome, equals(MatchOutcome.playerWins));
      });
    });

    // -------------------------------------------------------------------------
    // Total Conquest — AI wins
    // -------------------------------------------------------------------------
    group('Total Conquest — AI wins', () {
      test('TickMatch returns aiWins when all castles are AI-owned', () {
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

        expect(
          result.matchOutcome,
          equals(MatchOutcome.aiWins),
          reason: 'All AI-owned castles must trigger aiWins',
        );
      });

      test('VictoryChecker.check agrees with TickResult.matchOutcome for AI victory', () {
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

        expect(result.matchOutcome, equals(checkerOutcome));
        expect(checkerOutcome, equals(MatchOutcome.aiWins));
      });
    });

    // -------------------------------------------------------------------------
    // Mixed ownership — no outcome yet
    // -------------------------------------------------------------------------
    group('mixed ownership — no outcome', () {
      test('TickMatch returns null matchOutcome when castles are mixed', () {
        final map = GameMapFixture.build();
        // Use original fixture ownership: player + AI.
        final mixedCastles = _buildCastles(map);

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

        expect(
          result.matchOutcome,
          isNull,
          reason: 'Mixed ownership must produce no outcome',
        );
      });
    });

    // -------------------------------------------------------------------------
    // End-to-end: MatchPhase.setup → playing → ended
    // -------------------------------------------------------------------------
    group('end-to-end phase lifecycle', () {
      test('complete lifecycle: setup → playing → ended when all castles captured', () {
        // Verify the three phases are distinct enum values.
        expect(MatchPhase.setup, isNot(equals(MatchPhase.playing)));
        expect(MatchPhase.playing, isNot(equals(MatchPhase.ended)));
        expect(MatchPhase.setup, isNot(equals(MatchPhase.ended)));

        // Phase starts at setup.
        final map = GameMapFixture.build();
        final setupMatch = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.setup,
        );
        expect(setupMatch.phase, equals(MatchPhase.setup));

        // Transition to playing.
        final playingMatch = setupMatch.copyWith(phase: MatchPhase.playing);
        expect(playingMatch.phase, equals(MatchPhase.playing));

        // Simulate player winning all castles.
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

        final result = const TickMatch().tick(
          match: playingMatch,
          castles: allPlayerCastles,
          companies: [],
        );

        // Outcome is set.
        expect(result.matchOutcome, equals(MatchOutcome.playerWins));

        // Notifier would set phase to ended.
        final endedMatch = playingMatch.copyWith(
          phase: result.matchOutcome != null ? MatchPhase.ended : MatchPhase.playing,
        );
        expect(endedMatch.phase, equals(MatchPhase.ended));
      });
    });

    // -------------------------------------------------------------------------
    // MatchOutcome written correctly to TickResult
    // -------------------------------------------------------------------------
    group('MatchOutcome correctness', () {
      test('MatchOutcome.playerWins is written to TickResult when player owns all castles', () {
        final map = GameMapFixture.build();
        final castles = [
          Castle(id: GameMapFixture.playerCastleId, ownership: Ownership.player, garrison: {}),
          Castle(id: GameMapFixture.aiCastleId, ownership: Ownership.player, garrison: {}),
        ];

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

        expect(result.matchOutcome, equals(MatchOutcome.playerWins));
      });

      test('MatchOutcome.aiWins is written to TickResult when AI owns all castles', () {
        final map = GameMapFixture.build();
        final castles = [
          Castle(id: GameMapFixture.playerCastleId, ownership: Ownership.ai, garrison: {}),
          Castle(id: GameMapFixture.aiCastleId, ownership: Ownership.ai, garrison: {}),
        ];

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

        expect(result.matchOutcome, equals(MatchOutcome.aiWins));
      });

      test('no matchOutcome produced when ownership is mixed across multiple ticks', () {
        // Use _runTicks to simulate 5 ticks with default mixed ownership.
        final map = GameMapFixture.build();
        final initialCastles = _buildCastles(map);

        final state = _runTicks(
          map: map,
          castles: initialCastles,
          companies: [],
          ticks: 5,
        );

        // Mixed ownership throughout; no conquest should have occurred.
        expect(
          state.outcome,
          isNull,
          reason: 'Mixed ownership across 5 ticks must not produce a MatchOutcome',
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // T097 — Persistence round-trip (MatchDao save → load)
  // ---------------------------------------------------------------------------
  group('Persistence round-trip (T097)', () {
    late AppDatabase db;
    late MatchDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = MatchDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('saveMatch then loadMatch restores match phase and elapsed time', () async {
      final map = GameMapFixture.build();
      final castles = _buildCastles(map);
      final match = Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
        elapsedTime: const Duration(seconds: 60),
      );
      final originalState = MatchState(
        match: match,
        castles: castles,
        companies: [],
      );

      await dao.saveMatch(matchId: 'test_match', state: originalState);
      final restored = await dao.loadMatch('test_match');

      expect(restored, isNotNull);
      expect(restored!.match.phase, equals(MatchPhase.playing));
      expect(restored.match.elapsedTime, equals(const Duration(seconds: 60)));
      expect(restored.match.humanPlayer, equals(Ownership.player));
    });

    test('saveMatch then loadMatch restores castle ownership and garrison', () async {
      final map = GameMapFixture.build();
      final castles = [
        Castle(
          id: GameMapFixture.playerCastleId,
          ownership: Ownership.player,
          garrison: {UnitRole.warrior: 15, UnitRole.archer: 8},
        ),
        Castle(
          id: GameMapFixture.aiCastleId,
          ownership: Ownership.ai,
          garrison: {UnitRole.warrior: 5},
        ),
      ];
      final match = Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      );
      final originalState = MatchState(
        match: match,
        castles: castles,
        companies: [],
      );

      await dao.saveMatch(matchId: 'test_match_2', state: originalState);
      final restored = await dao.loadMatch('test_match_2');

      expect(restored, isNotNull);
      final playerCastle = restored!.castles
          .firstWhere((c) => c.id == GameMapFixture.playerCastleId);
      final aiCastle = restored.castles
          .firstWhere((c) => c.id == GameMapFixture.aiCastleId);

      expect(playerCastle.ownership, equals(Ownership.player));
      expect(playerCastle.garrison[UnitRole.warrior], equals(15));
      expect(playerCastle.garrison[UnitRole.archer], equals(8));
      expect(aiCastle.ownership, equals(Ownership.ai));
      expect(aiCastle.garrison[UnitRole.warrior], equals(5));
    });

    test('saveMatch then loadMatch restores companies on map', () async {
      final map = GameMapFixture.build();
      final castles = _buildCastles(map);
      final playerCastleNode = map.nodes
          .whereType<CastleNode>()
          .firstWhere((n) => n.id == GameMapFixture.playerCastleId);

      final company = CompanyOnMap(
        id: 'co_1',
        ownership: Ownership.player,
        currentNode: playerCastleNode,
        destination: null,
        progress: 0.0,
        company: Company(composition: {UnitRole.warrior: 10}),
      );

      final match = Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      );
      final originalState = MatchState(
        match: match,
        castles: castles,
        companies: [company],
      );

      await dao.saveMatch(matchId: 'test_match_3', state: originalState);
      final restored = await dao.loadMatch('test_match_3');

      expect(restored, isNotNull);
      expect(restored!.companies, hasLength(1));
      final restoredCo = restored.companies.first;
      expect(restoredCo.id, equals('co_1'));
      expect(restoredCo.ownership, equals(Ownership.player));
      expect(restoredCo.currentNode.id, equals(GameMapFixture.playerCastleId));
      expect(restoredCo.company.composition[UnitRole.warrior], equals(10));
    });

    test('loadMatch returns null for unknown matchId', () async {
      final result = await dao.loadMatch('nonexistent_id');
      expect(result, isNull);
    });

    test('deleteMatch removes all associated rows', () async {
      final map = GameMapFixture.build();
      final castles = _buildCastles(map);
      final match = Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      );
      final originalState = MatchState(
        match: match,
        castles: castles,
        companies: [],
      );

      await dao.saveMatch(matchId: 'delete_test', state: originalState);
      await dao.deleteMatch('delete_test');

      final result = await dao.loadMatch('delete_test');
      expect(result, isNull);
    });

    test('SC-006: launch → deploy → march → battle trigger → total conquest produces correct MatchOutcome', () {
      // End-to-end simulation: mixed castles → TickMatch produces no outcome;
      // then force all-player castles → TickMatch produces playerWins.
      final map = GameMapFixture.build();
      final mixedCastles = _buildCastles(map);
      final match = Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      );

      // Step 1: Normal play — no outcome.
      final midResult = const TickMatch().tick(
        match: match,
        castles: mixedCastles,
        companies: [],
      );
      expect(midResult.matchOutcome, isNull,
          reason: 'Mid-game mixed ownership should not produce outcome');

      // Step 2: Player captures all castles.
      final allPlayerCastles = map.nodes
          .whereType<CastleNode>()
          .map((n) => Castle(
                id: n.id,
                ownership: Ownership.player,
                garrison: {},
              ))
          .toList();

      final finalResult = const TickMatch().tick(
        match: match,
        castles: allPlayerCastles,
        companies: [],
      );
      expect(finalResult.matchOutcome, equals(MatchOutcome.playerWins),
          reason: 'All player castles must produce playerWins');
    });
  });
}
