import 'package:drift/drift.dart';

/// Drift table for persisting a single match session.
///
/// One row represents the current (or last) ongoing match.
/// The JSON columns store serialised [Match] + [Castle] + [CompanyOnMap] snapshots.
class MatchesTable extends Table {
  /// Unique match identifier (UUID v4 string).
  TextColumn get id => text()();

  /// ISO-8601 timestamp when the match was created.
  TextColumn get createdAt => text()();

  /// ISO-8601 timestamp of the last persist call.
  TextColumn get updatedAt => text()();

  /// Current [MatchPhase] as a string ('setup' | 'playing' | 'inBattle' | 'ended').
  TextColumn get phase => text()();

  /// [MatchOutcome] as a string ('playerWins' | 'aiWins') or empty string when null.
  TextColumn get outcome => text().withDefault(const Constant(''))();

  /// Total elapsed game time in seconds.
  IntColumn get elapsedSeconds => integer().withDefault(const Constant(0))();

  /// Human player ownership string ('player' | 'ai').
  TextColumn get humanPlayer => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
