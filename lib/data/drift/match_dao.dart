import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:iron_and_stone/data/drift/app_database.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/match_notifier.dart' show MatchState;

// ---------------------------------------------------------------------------
// Serialisation helpers
// ---------------------------------------------------------------------------

String _ownershipToString(Ownership o) => switch (o) {
      Ownership.player => 'player',
      Ownership.ai => 'ai',
      Ownership.neutral => 'neutral',
    };

Ownership _ownershipFromString(String s) => switch (s) {
      'ai' => Ownership.ai,
      'neutral' => Ownership.neutral,
      _ => Ownership.player,
    };

String _phaseToString(MatchPhase p) => switch (p) {
      MatchPhase.setup => 'setup',
      MatchPhase.playing => 'playing',
      MatchPhase.inBattle => 'inBattle',
      MatchPhase.ended => 'ended',
    };

MatchPhase _phaseFromString(String s) => switch (s) {
      'setup' => MatchPhase.setup,
      'inBattle' => MatchPhase.inBattle,
      'ended' => MatchPhase.ended,
      _ => MatchPhase.playing,
    };

/// Encodes a [Map<UnitRole, int>] as a JSON string.
String _encodeGarrison(Map<UnitRole, int> garrison) {
  final encoded = {
    for (final e in garrison.entries) e.key.name: e.value,
  };
  return jsonEncode(encoded);
}

/// Decodes a JSON string back to [Map<UnitRole, int>].
Map<UnitRole, int> _decodeGarrison(String json) {
  final raw = jsonDecode(json) as Map<String, dynamic>;
  final result = <UnitRole, int>{};
  for (final e in raw.entries) {
    final role = UnitRole.values.where((r) => r.name == e.key).firstOrNull;
    if (role != null) {
      result[role] = (e.value as num).toInt();
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// MatchDao
// ---------------------------------------------------------------------------

/// Data Access Object for match-state persistence.
///
/// Provides [saveMatch], [loadMatch], and [deleteMatch] operations.
/// Maps domain [MatchState] ↔ Drift rows in [MatchesTable], [CastlesTable],
/// and [CompaniesTable].
///
/// Only one match is persisted at a time (single-player MVP).
class MatchDao {
  final AppDatabase _db;

  const MatchDao(this._db);

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  /// Persist the current [MatchState] as an atomic transaction.
  ///
  /// Upserts the match row and replaces all castle / company rows for this
  /// match ID.
  Future<void> saveMatch({
    required String matchId,
    required MatchState state,
  }) async {
    await _db.transaction(() async {
      // --- Match row ---
      final now = DateTime.now().toIso8601String();
      final outcome = state.matchOutcome?.name ?? '';

      await _db
          .into(_db.matchesTable)
          .insertOnConflictUpdate(MatchesTableCompanion(
            id: Value(matchId),
            createdAt: Value(now),
            updatedAt: Value(now),
            phase: Value(_phaseToString(state.match.phase)),
            outcome: Value(outcome),
            elapsedSeconds:
                Value(state.match.elapsedTime.inSeconds),
            humanPlayer:
                Value(_ownershipToString(state.match.humanPlayer)),
          ));

      // --- Castle rows ---
      // Delete existing rows for this match, then re-insert.
      await (_db.delete(_db.castlesTable)
            ..where((t) => t.matchId.equals(matchId)))
          .go();

      for (final castle in state.castles) {
        await _db.into(_db.castlesTable).insert(CastlesTableCompanion(
              id: Value(castle.id),
              matchId: Value(matchId),
              ownership: Value(_ownershipToString(castle.ownership)),
              garrisonJson: Value(_encodeGarrison(castle.garrison)),
            ));
      }

      // --- Company rows ---
      await (_db.delete(_db.companiesTable)
            ..where((t) => t.matchId.equals(matchId)))
          .go();

      for (final co in state.companies) {
        await _db.into(_db.companiesTable).insert(CompaniesTableCompanion(
              id: Value(co.id),
              matchId: Value(matchId),
              ownership: Value(_ownershipToString(co.ownership)),
              currentNodeId: Value(co.currentNode.id),
              destinationNodeId: Value(co.destination?.id ?? ''),
              progress: Value(co.progress),
              compositionJson:
                  Value(_encodeGarrison(co.company.composition)),
            ));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Restore a [MatchState] from the database by [matchId].
  ///
  /// Returns `null` if no match with [matchId] exists.
  /// Uses [GameMapFixture.build()] for the map (fixed map — not persisted).
  Future<MatchState?> loadMatch(String matchId) async {
    // Load match row.
    final matchRow = await (_db.select(_db.matchesTable)
          ..where((t) => t.id.equals(matchId)))
        .getSingleOrNull();
    if (matchRow == null) return null;

    final map = GameMapFixture.build();

    // Rebuild map-node lookup.
    final nodeById = {for (final n in map.nodes) n.id: n};

    // Load castle rows.
    final castleRows = await (_db.select(_db.castlesTable)
          ..where((t) => t.matchId.equals(matchId)))
        .get();

    final castles = castleRows.map((row) {
      return Castle(
        id: row.id,
        ownership: _ownershipFromString(row.ownership),
        garrison: _decodeGarrison(row.garrisonJson),
      );
    }).toList();

    // Load company rows.
    final companyRows = await (_db.select(_db.companiesTable)
          ..where((t) => t.matchId.equals(matchId)))
        .get();

    final companies = <CompanyOnMap>[];
    for (final row in companyRows) {
      final currentNode = nodeById[row.currentNodeId];
      if (currentNode == null) continue; // skip if node no longer exists

      final destination = row.destinationNodeId.isNotEmpty
          ? nodeById[row.destinationNodeId]
          : null;

      final composition = _decodeGarrison(row.compositionJson);

      companies.add(CompanyOnMap(
        id: row.id,
        ownership: _ownershipFromString(row.ownership),
        currentNode: currentNode,
        destination: destination,
        progress: row.progress,
        company: Company(composition: composition),
      ));
    }

    final match = Match(
      map: map,
      humanPlayer: _ownershipFromString(matchRow.humanPlayer),
      elapsedTime: Duration(seconds: matchRow.elapsedSeconds),
      phase: _phaseFromString(matchRow.phase),
    );

    return MatchState(
      match: match,
      castles: castles,
      companies: companies,
    );
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Delete all rows associated with [matchId].
  Future<void> deleteMatch(String matchId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.matchesTable)
            ..where((t) => t.id.equals(matchId)))
          .go();
      await (_db.delete(_db.castlesTable)
            ..where((t) => t.matchId.equals(matchId)))
          .go();
      await (_db.delete(_db.companiesTable)
            ..where((t) => t.matchId.equals(matchId)))
          .go();
    });
  }
}
