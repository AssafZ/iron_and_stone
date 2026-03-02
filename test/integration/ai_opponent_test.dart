// T082 — Failing integration test for AI opponent autonomous behaviour.
// Red-Green-Refactor: tests must FAIL before AiController is wired into TickMatch.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/tick_match.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build the standard fixture castles with a generous AI garrison (>= 10 units
/// on each role) so that the AI's deploy threshold is immediately met.
List<Castle> _buildCastles(GameMap map) {
  return map.nodes.whereType<CastleNode>().map((node) {
    final garrison = node.ownership == Ownership.ai
        ? {UnitRole.warrior: 30, UnitRole.archer: 10}
        : {UnitRole.warrior: 10};
    return Castle(id: node.id, ownership: node.ownership, garrison: garrison);
  }).toList();
}

/// Advance a [TickResult] state forward by [ticks] ticks using [TickMatch].
({List<Castle> castles, List<CompanyOnMap> companies}) _runTicks({
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
  }

  return (castles: currentCastles, companies: currentCompanies);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AI opponent integration', () {
    test(
        'AI deploys >= 1 Company after 30 s (3 ticks) when garrison >= 10 units',
        () {
      final map = GameMapFixture.build();
      final castles = _buildCastles(map);

      final result = _runTicks(
        map: map,
        castles: castles,
        companies: [],
        ticks: 3, // 3 ticks × 10 s = 30 s
      );

      final aiCompanies = result.companies
          .where((c) => c.ownership == Ownership.ai)
          .toList();

      expect(
        aiCompanies.length,
        greaterThanOrEqualTo(1),
        reason: 'AI must have deployed at least 1 Company within 30 s',
      );
    });

    test(
        'AI Company has moved toward player castle after 60 s (6 ticks)',
        () {
      final map = GameMapFixture.build();
      final castles = _buildCastles(map);

      // Run 3 ticks to get initial deployment.
      final afterDeploy = _runTicks(
        map: map,
        castles: castles,
        companies: [],
        ticks: 3,
      );

      // Run 3 more ticks (total 6 = 60 s).
      final afterMove = _runTicks(
        map: map,
        castles: afterDeploy.castles,
        companies: afterDeploy.companies,
        ticks: 3,
      );

      final aiCompanies = afterMove.companies
          .where((c) => c.ownership == Ownership.ai)
          .toList();

      expect(aiCompanies, isNotEmpty,
          reason: 'AI Company must still exist after 60 s');

      final aiCastleNode = map.nodes
          .whereType<CastleNode>()
          .firstWhere((n) => n.ownership == Ownership.ai);

      // At least one AI Company should have moved away from the AI castle
      // (either progress > 0 or on a different node).
      final hasAdvanced = aiCompanies.any((co) =>
          co.currentNode.id != aiCastleNode.id || co.progress > 0.0);

      expect(
        hasAdvanced,
        isTrue,
        reason:
            'AI Company must have moved toward a player/unoccupied castle within 60 s',
      );
    });

    test(
        'TickResult contains AI deploy action when AI garrison >= 10 units',
        () {
      // T085 — verifying that TickMatch returns a deploy action in TickResult
      // when the AI garrison meets the threshold.
      final map = GameMapFixture.build();
      final castles = _buildCastles(map);
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

      // After one tick, the AI should have deployed a Company.
      final aiCompanies = result.companies
          .where((c) => c.ownership == Ownership.ai)
          .toList();

      expect(
        aiCompanies.length,
        greaterThanOrEqualTo(1),
        reason: 'TickResult.companies must include an AI Company after first tick with garrison >= 10',
      );
    });
  });
}
