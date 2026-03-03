import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/rules/growth_engine.dart';

/// Use case: apply one castle growth tick.
///
/// A thin wrapper around [GrowthEngine] that satisfies the use-case boundary
/// in the domain layer. Accepts a [Castle] and returns a new [Castle] with
/// updated garrison counts.
///
/// Pure Dart — zero Flutter/state imports.
final class TickCastleGrowth {
  const TickCastleGrowth();

  /// Apply one growth tick to [castle] and return the updated [Castle].
  Castle tick(Castle castle) => const GrowthEngine().tick(castle);
}
