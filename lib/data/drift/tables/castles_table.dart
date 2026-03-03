import 'package:drift/drift.dart';

/// Drift table for persisting [Castle] garrison state per match.
///
/// Each row represents the persisted state of one castle within a match.
class CastlesTable extends Table {
  /// Castle node ID (matches the CastleNode id on the fixed map).
  TextColumn get id => text()();

  /// Foreign key: the owning match's ID.
  TextColumn get matchId => text()();

  /// Ownership string: 'player' | 'ai' | 'neutral'.
  TextColumn get ownership => text()();

  /// JSON-encoded garrison — role name to count.
  /// e.g. '{"peasant":5,"warrior":20,"knight":3,"archer":8,"catapult":1}'
  TextColumn get garrisonJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id, matchId};
}
