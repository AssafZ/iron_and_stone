import 'package:drift/drift.dart';

/// Drift table for persisting [CompanyOnMap] state per match.
///
/// Each row represents a single Company on the map at the time of last persist.
class CompaniesTable extends Table {
  /// Unique identifier for this Company instance.
  TextColumn get id => text()();

  /// Foreign key: the owning match's ID.
  TextColumn get matchId => text()();

  /// Ownership string: 'player' | 'ai'.
  TextColumn get ownership => text()();

  /// Current node ID the Company is at or most recently passed through.
  TextColumn get currentNodeId => text()();

  /// Destination node ID, or empty string when stationary.
  TextColumn get destinationNodeId => text().withDefault(const Constant(''))();

  /// Fractional progress toward the next node [0.0, 1.0).
  RealColumn get progress => real().withDefault(const Constant(0.0))();

  /// JSON-encoded composition — role name to count.
  /// e.g. '{"warrior":10,"archer":5}'
  TextColumn get compositionJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
