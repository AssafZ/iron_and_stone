// T087 — Failing unit tests for VictoryChecker.
// Red-Green-Refactor: tests FAIL before VictoryChecker exists, then GREEN after.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/victory_checker.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Castle _castle(String id, Ownership ownership, {int warriors = 5}) => Castle(
      id: id,
      ownership: ownership,
      garrison: {UnitRole.warrior: warriors},
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('VictoryChecker', () {
    // -------------------------------------------------------------------------
    // All-player castles → playerWins
    // -------------------------------------------------------------------------
    group('all castles owned by player', () {
      test('two-castle map returns MatchOutcome.playerWins', () {
        final castles = [
          _castle('c1', Ownership.player),
          _castle('c2', Ownership.player),
        ];

        final result = const VictoryChecker().check(castles);

        expect(result, equals(MatchOutcome.playerWins));
      });

      test('four-castle map all player returns MatchOutcome.playerWins', () {
        final castles = List.generate(
          4,
          (i) => _castle('c$i', Ownership.player),
        );

        final result = const VictoryChecker().check(castles);

        expect(result, equals(MatchOutcome.playerWins));
      });

      test('single-castle map owned by player returns MatchOutcome.playerWins', () {
        final castles = [_castle('c1', Ownership.player)];

        final result = const VictoryChecker().check(castles);

        expect(result, equals(MatchOutcome.playerWins));
      });
    });

    // -------------------------------------------------------------------------
    // All-AI castles → aiWins
    // -------------------------------------------------------------------------
    group('all castles owned by AI', () {
      test('two-castle map returns MatchOutcome.aiWins', () {
        final castles = [
          _castle('c1', Ownership.ai),
          _castle('c2', Ownership.ai),
        ];

        final result = const VictoryChecker().check(castles);

        expect(result, equals(MatchOutcome.aiWins));
      });

      test('four-castle map all AI returns MatchOutcome.aiWins', () {
        final castles = List.generate(
          4,
          (i) => _castle('c$i', Ownership.ai),
        );

        final result = const VictoryChecker().check(castles);

        expect(result, equals(MatchOutcome.aiWins));
      });

      test('single-castle map owned by AI returns MatchOutcome.aiWins', () {
        final castles = [_castle('c1', Ownership.ai)];

        final result = const VictoryChecker().check(castles);

        expect(result, equals(MatchOutcome.aiWins));
      });
    });

    // -------------------------------------------------------------------------
    // Mixed ownership → null (game still in progress)
    // -------------------------------------------------------------------------
    group('mixed ownership', () {
      test('one player + one AI castle returns null', () {
        final castles = [
          _castle('c1', Ownership.player),
          _castle('c2', Ownership.ai),
        ];

        final result = const VictoryChecker().check(castles);

        expect(result, isNull);
      });

      test('player + AI + neutral returns null', () {
        final castles = [
          _castle('c1', Ownership.player),
          _castle('c2', Ownership.ai),
          _castle('c3', Ownership.neutral),
        ];

        final result = const VictoryChecker().check(castles);

        expect(result, isNull);
      });

      test('all neutral castles returns null', () {
        final castles = [
          _castle('c1', Ownership.neutral),
          _castle('c2', Ownership.neutral),
        ];

        final result = const VictoryChecker().check(castles);

        expect(result, isNull);
      });

      test('two player + one AI returns null', () {
        final castles = [
          _castle('c1', Ownership.player),
          _castle('c2', Ownership.player),
          _castle('c3', Ownership.ai),
        ];

        final result = const VictoryChecker().check(castles);

        expect(result, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Edge case: empty castle list
    // -------------------------------------------------------------------------
    group('edge cases', () {
      test('empty castle list returns null', () {
        final result = const VictoryChecker().check([]);

        expect(result, isNull);
      });

      test('single-castle map with neutral ownership returns null', () {
        final castles = [_castle('c1', Ownership.neutral)];

        final result = const VictoryChecker().check(castles);

        expect(result, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // MatchOutcome enum values
    // -------------------------------------------------------------------------
    group('MatchOutcome enum', () {
      test('playerWins and aiWins are distinct values', () {
        expect(MatchOutcome.playerWins, isNot(equals(MatchOutcome.aiWins)));
      });
    });
  });
}
