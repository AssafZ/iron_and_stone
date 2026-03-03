import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/value_objects/soldier_count.dart';

/// An in-transit group of up to 50 soldiers.
///
/// [composition] maps each [UnitRole] to the number of that role present.
/// Total soldiers across all roles must not exceed [SoldierCount.max] (50).
/// The [movementSpeed] is derived as the minimum speed among all roles present.
final class Company {
  /// Soldier counts by role. Zero-count entries do not contribute to [totalSoldiers].
  final Map<UnitRole, int> composition;

  /// Total soldiers (sum of all role counts). Validated ∈ [0, 50].
  final SoldierCount totalSoldiers;

  /// Movement speed: the minimum speed among roles that have at least 1 soldier.
  /// Returns 0 for an empty company.
  final int movementSpeed;

  Company({required Map<UnitRole, int> composition})
      : composition = Map.unmodifiable(composition),
        totalSoldiers = _computeTotal(composition),
        movementSpeed = _computeSpeed(composition);

  static SoldierCount _computeTotal(Map<UnitRole, int> composition) {
    final total = composition.values.fold(0, (sum, count) => sum + count);
    return SoldierCount(total); // throws ArgumentError if > 50
  }

  static int _computeSpeed(Map<UnitRole, int> composition) {
    final presentRoles = composition.entries
        .where((e) => e.value > 0)
        .map((e) => e.key.speed);
    if (presentRoles.isEmpty) return 0;
    return presentRoles.reduce((a, b) => a < b ? a : b);
  }

  /// Returns a new [Company] with the given fields replaced.
  Company copyWith({Map<UnitRole, int>? composition}) {
    return Company(composition: composition ?? this.composition);
  }

  @override
  String toString() =>
      'Company(total=${totalSoldiers.value}, speed=$movementSpeed, composition=$composition)';
}
