// T082 — Integration tests for AI opponent autonomous behaviour.
// AI starts with a pre-placed company and issues MoveActions — no garrison deploy.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
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

/// Build the standard fixture castles with empty garrisons.
List<Castle> _buildCastles(GameMap map) {
  return map.nodes.whereType<CastleNode>().map((node) {
    return Castle(id: node.id, ownership: node.ownership, garrison: const {});
  }).toList();
}

/// Build the starting companies: one per side, stationed at their castle.
List<CompanyOnMap> _buildStartingCompanies(GameMap map) {
  return map.nodes.whereType<CastleNode>().map((node) {
    return CompanyOnMap(
      id: '${node.ownership.name}_co0',
      ownership: node.ownership,
      currentNode: node,
      company: Company(composition: {
        UnitRole.warrior: 3,
        UnitRole.archer: 3,
        UnitRole.peasant: 2,
        UnitRole.knight: 1,
        UnitRole.catapult: 1,
      }),
    );
  }).toList();
}

/// Advance state forward by [ticks] ticks using [TickMatch].
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
        'AI company exists from game start (no deployment needed)',
        () {
      final map = GameMapFixture.build();
      final companies = _buildStartingCompanies(map);

      final aiCompanies = companies
          .where((c) => c.ownership == Ownership.ai)
          .toList();

      expect(
        aiCompanies.length,
        greaterThanOrEqualTo(1),
        reason: 'AI must have a Company from game start',
      );
    });

    test(
        'AI Company has moved toward player castle after 30 s (3 ticks)',
        () {
      final map = GameMapFixture.build();
      final castles = _buildCastles(map);
      final companies = _buildStartingCompanies(map);

      // Run 3 ticks (30 s).
      final result = _runTicks(
        map: map,
        castles: castles,
        companies: companies,
        ticks: 3,
      );

      final aiCompanies = result.companies
          .where((c) => c.ownership == Ownership.ai)
          .toList();

      expect(aiCompanies, isNotEmpty,
          reason: 'AI Company must still exist after 30 s');

      final aiCastleNode = map.nodes
          .whereType<CastleNode>()
          .firstWhere((n) => n.ownership == Ownership.ai);

      // At least one AI Company should have moved away from the AI castle.
      final hasAdvanced = aiCompanies.any((co) =>
          co.currentNode.id != aiCastleNode.id || co.progress > 0.0);

      expect(
        hasAdvanced,
        isTrue,
        reason: 'AI Company must have moved toward a player/unoccupied castle within 30 s',
      );
    });

    test(
        'AI Company has a destination assigned after first tick',
        () {
      final map = GameMapFixture.build();
      final castles = _buildCastles(map);
      final companies = _buildStartingCompanies(map);
      final match = Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      );

      final result = const TickMatch().tick(
        match: match,
        castles: castles,
        companies: companies,
      );

      // After one tick, the AI should have received a MoveAction.
      final aiCompanies = result.companies
          .where((c) => c.ownership == Ownership.ai)
          .toList();

      expect(aiCompanies, isNotEmpty);
      final hasDestination = aiCompanies.any((c) => c.destination != null);
      expect(
        hasDestination,
        isTrue,
        reason: 'AI Company must have a destination after the first tick',
      );
    });
  });
}
