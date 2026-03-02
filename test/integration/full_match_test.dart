// T088 — Failing integration test: full match from launch to Total Conquest.
// Red-Green-Refactor: tests confirm MatchPhase transitions and correct MatchOutcome.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/victory_checker.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/tick_match.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

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
}
