import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';

/// Result of a single growth tick (type alias for clarity).
typedef CastleGrowthResult = Castle;

/// Domain rule: compute one castle growth tick.
///
/// Rules:
/// - Base growth: 1 unit per role per tick (multiplied by [Castle.growthRateMultiplier]).
/// - Per-role slot cap: 50 — a role at 50 does not grow further (other roles unaffected).
/// - Castle Cap: [Castle.effectiveCap] — if total garrison equals or exceeds the effective
///   cap, ALL growth halts for this tick.
/// - All roles in [UnitRole.values] are considered, initialising absent ones at 0.
///
/// Pure Dart — zero Flutter dependencies.
final class GrowthEngine {
  /// Base number of units added per role per tick at multiplier 1.0.
  static const int _baseGrowthPerTick = 1;

  const GrowthEngine();

  /// Apply one growth tick to [castle] and return the updated [Castle].
  ///
  /// The original [castle] is never mutated.
  CastleGrowthResult tick(Castle castle) {
    // Total garrison check against effective cap (which already includes
    // the Peasant multiplier).
    final total = _totalGarrison(castle);
    if (total >= castle.effectiveCap) {
      return castle; // at cap — no growth at all
    }

    final multiplier = castle.growthRateMultiplier;
    final updated = Map<UnitRole, int>.from(castle.garrison);

    for (final role in UnitRole.values) {
      final current = updated[role] ?? 0;
      if (current >= 50) continue; // per-role slot cap

      // Compute effective growth: at least 1, scaled by multiplier.
      final rawGrowth = (_baseGrowthPerTick * multiplier).floor();
      final growth = rawGrowth < 1 ? 1 : rawGrowth;

      // Do not exceed per-role slot cap of 50.
      updated[role] = (current + growth).clamp(0, 50);
    }

    return castle.copyWith(garrison: updated);
  }

  static int _totalGarrison(Castle castle) =>
      castle.garrison.values.fold(0, (sum, v) => sum + v);
}
