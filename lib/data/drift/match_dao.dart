import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:iron_and_stone/data/drift/app_database.dart';
import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';
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

/// Encodes a [Battle] to a JSON string for storage in [BattlesTable.battleJson].
///
/// Serialises: roundNumber, kind, outcome, highGroundActive, roundLog,
/// attackerHp, defenderHp, attackers (compositions), defenders (compositions).
String _encodeBattle(Battle battle) {
  List<Map<String, dynamic>> encodeCompanies(List<Company> companies) {
    return companies.map((c) {
      return {
        'composition': {
          for (final e in c.composition.entries) e.key.name: e.value,
        },
      };
    }).toList();
  }

  Map<String, int>? hp = battle.attackerHp != null
      ? Map<String, int>.from(battle.attackerHp!)
      : null;
  Map<String, int>? dhp = battle.defenderHp != null
      ? Map<String, int>.from(battle.defenderHp!)
      : null;

  return jsonEncode({
    'roundNumber': battle.roundNumber,
    'kind': battle.kind.name,
    'outcome': battle.outcome?.name,
    'highGroundActive': battle.highGroundActive,
    'roundLog': battle.roundLog,
    'attackerHp': hp,
    'defenderHp': dhp,
    'attackers': encodeCompanies(battle.attackers),
    'defenders': encodeCompanies(battle.defenders),
    if (battle.initialAttackers != null)
      'initialAttackers': encodeCompanies(battle.initialAttackers!),
    if (battle.initialDefenders != null)
      'initialDefenders': encodeCompanies(battle.initialDefenders!),
  });
}

/// Decodes a [Battle] from the JSON string stored in [BattlesTable.battleJson].
Battle _decodeBattle(String json) {
  final raw = jsonDecode(json) as Map<String, dynamic>;

  Company decodeCompany(Map<String, dynamic> map) {
    final compMap = map['composition'] as Map<String, dynamic>;
    final composition = <UnitRole, int>{};
    for (final e in compMap.entries) {
      final role = UnitRole.values.where((r) => r.name == e.key).firstOrNull;
      if (role != null) composition[role] = (e.value as num).toInt();
    }
    return Company(composition: composition);
  }

  final attackers = (raw['attackers'] as List<dynamic>)
      .map((e) => decodeCompany(e as Map<String, dynamic>))
      .toList();
  final defenders = (raw['defenders'] as List<dynamic>)
      .map((e) => decodeCompany(e as Map<String, dynamic>))
      .toList();

  BattleOutcome? outcome;
  final outcomeStr = raw['outcome'] as String?;
  if (outcomeStr != null) {
    outcome = BattleOutcome.values
        .where((o) => o.name == outcomeStr)
        .firstOrNull;
  }

  final kind = BattleKind.values
      .where((k) => k.name == (raw['kind'] as String? ?? 'roadCollision'))
      .firstOrNull ?? BattleKind.roadCollision;

  SideHp? attackerHp;
  final rawAHp = raw['attackerHp'];
  if (rawAHp != null) {
    attackerHp = {
      for (final e in (rawAHp as Map<String, dynamic>).entries)
        e.key: (e.value as num).toInt(),
    };
  }

  SideHp? defenderHp;
  final rawDHp = raw['defenderHp'];
  if (rawDHp != null) {
    defenderHp = {
      for (final e in (rawDHp as Map<String, dynamic>).entries)
        e.key: (e.value as num).toInt(),
    };
  }

  final roundLog = (raw['roundLog'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [];

  return Battle(
    attackers: attackers,
    defenders: defenders,
    roundNumber: (raw['roundNumber'] as num?)?.toInt() ?? 0,
    kind: kind,
    outcome: outcome,
    highGroundActive: raw['highGroundActive'] as bool? ?? false,
    roundLog: roundLog,
    attackerHp: attackerHp,
    defenderHp: defenderHp,
    initialAttackers: (raw['initialAttackers'] as List<dynamic>?)
        ?.map((e) => decodeCompany(e as Map<String, dynamic>))
        .toList(),
    initialDefenders: (raw['initialDefenders'] as List<dynamic>?)
        ?.map((e) => decodeCompany(e as Map<String, dynamic>))
        .toList(),
  );
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
              battleId: Value(co.battleId ?? ''),
              midRoadCurrentNodeId:
                  Value(co.midRoadDestination?.currentNodeId ?? ''),
              midRoadNextNodeId:
                  Value(co.midRoadDestination?.nextNodeId ?? ''),
              midRoadProgress:
                  Value(co.midRoadDestination?.progress ?? 0.0),
            ));
      }

      // --- Battle rows ---
      await (_db.delete(_db.battlesTable)
            ..where((t) => t.matchId.equals(matchId)))
          .go();

      for (final ab in state.activeBattles) {
        await _db.into(_db.battlesTable).insert(BattlesTableCompanion(
              id: Value(ab.id),
              matchId: Value(matchId),
              nodeId: Value(ab.nodeId),
              attackerCompanyIds:
                  Value(jsonEncode(ab.attackerCompanyIds)),
              defenderCompanyIds:
                  Value(jsonEncode(ab.defenderCompanyIds)),
              attackerOwnership:
                  Value(_ownershipToString(ab.attackerOwnership)),
              battleJson: Value(_encodeBattle(ab.battle)),
            ));
      }
      // TODO(cleanup): growthRemainder persistence not yet implemented
    }); // end transaction
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
      // Empty string in DB → null battleId on the domain entity.
      final battleId = row.battleId.isNotEmpty ? row.battleId : null;

      // Restore midRoadDestination if all three columns are populated.
      RoadPosition? midRoadDestination;
      if (row.midRoadCurrentNodeId.isNotEmpty &&
          row.midRoadNextNodeId.isNotEmpty) {
        midRoadDestination = RoadPosition(
          currentNodeId: row.midRoadCurrentNodeId,
          nextNodeId: row.midRoadNextNodeId,
          progress: row.midRoadProgress,
        );
      }

      companies.add(CompanyOnMap(
        id: row.id,
        ownership: _ownershipFromString(row.ownership),
        currentNode: currentNode,
        destination: destination,
        progress: row.progress,
        company: Company(composition: composition),
        battleId: battleId,
        midRoadDestination: midRoadDestination,
      ));
    }

    // Load battle rows.
    final battleRows = await (_db.select(_db.battlesTable)
          ..where((t) => t.matchId.equals(matchId)))
        .get();

    final activeBattles = battleRows.map((row) {
      final attackerIds =
          (jsonDecode(row.attackerCompanyIds) as List<dynamic>)
              .map((e) => e as String)
              .toList();
      final defenderIds =
          (jsonDecode(row.defenderCompanyIds) as List<dynamic>)
              .map((e) => e as String)
              .toList();
      return ActiveBattle(
        nodeId: row.nodeId,
        attackerCompanyIds: attackerIds,
        defenderCompanyIds: defenderIds,
        attackerOwnership: _ownershipFromString(row.attackerOwnership),
        battle: _decodeBattle(row.battleJson),
      );
    }).toList();

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
      activeBattles: activeBattles,
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
      await (_db.delete(_db.battlesTable)
            ..where((t) => t.matchId.equals(matchId)))
          .go();
    });
  }
}
