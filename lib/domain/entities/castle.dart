import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// A castle node's game state: garrison pool, ownership, cap, and growth rate.
///
/// [garrison] is a flat [Map<UnitRole, int>] — total units by role available
/// for deployment. It is NOT a list of Company slots.
final class Castle {
  static const int _baseCap = 250;

  /// Unique identifier (matches the corresponding [CastleNode] id).
  final String id;

  /// Current owner of this castle.
  final Ownership ownership;

  /// Flat pool of available units by role.
  final Map<UnitRole, int> garrison;

  /// Base Castle Cap (constant). Effective cap may be higher due to Peasants.
  int get baseCap => _baseCap;

  /// Growth-rate multiplier: 1.0 + 0.05 × peasantCount.
  double get growthRateMultiplier {
    final peasants = garrison[UnitRole.peasant] ?? 0;
    return 1.0 + 0.05 * peasants;
  }

  /// Effective Castle Cap: baseCap × growthRateMultiplier (rounded to int).
  int get effectiveCap => (baseCap * growthRateMultiplier).round();

  Castle({
    required this.id,
    required this.ownership,
    required Map<UnitRole, int> garrison,
  }) : garrison = Map.unmodifiable(garrison);

  /// Returns a new [Castle] with the given fields replaced.
  Castle copyWith({
    String? id,
    Ownership? ownership,
    Map<UnitRole, int>? garrison,
  }) {
    return Castle(
      id: id ?? this.id,
      ownership: ownership ?? this.ownership,
      garrison: garrison ?? this.garrison,
    );
  }

  @override
  String toString() => 'Castle(id=$id, owner=$ownership, garrison=$garrison)';
}
