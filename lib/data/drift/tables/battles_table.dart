import 'package:drift/drift.dart';

/// Drift table for persisting [ActiveBattle] state per match.
///
/// Each row represents one active battle that has been triggered but not yet
/// resolved. Rows are deleted when the battle completes (outcome != null).
class BattlesTable extends Table {
  /// Unique battle identifier — always `"battle_<nodeId>"`.
  TextColumn get id => text()();

  /// Foreign key: the owning match's ID.
  TextColumn get matchId => text()();

  /// The map node ID where this battle is occurring.
  TextColumn get nodeId => text()();

  /// JSON-encoded list of attacker company IDs.
  /// e.g. '["co_1","co_3"]'
  TextColumn get attackerCompanyIds => text()();

  /// JSON-encoded list of defender company IDs.
  /// e.g. '["co_2"]'
  TextColumn get defenderCompanyIds => text()();

  /// Serialized [Ownership] of the attacking side: 'player' | 'ai'.
  TextColumn get attackerOwnership => text()();

  /// JSON-encoded [Battle] snapshot (full round state, HP maps, outcome).
  TextColumn get battleJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
