import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';

/// Context describing the terrain and battle situation for bonus calculation.
final class BattleContext {
  /// True if the battle is taking place on a road segment.
  final bool isOnRoad;

  /// True if the defending side is inside a castle (castle-assault battle).
  final bool isDefendingCastle;

  /// Whether the Archer High Ground bonus is currently active.
  /// Computed from [TerrainBonus.highGroundActive] before each round.
  final bool highGroundActive;

  const BattleContext({
    required this.isOnRoad,
    required this.isDefendingCastle,
    this.highGroundActive = false,
  });
}

/// Applies terrain-based damage bonuses and damage-reduction rules.
///
/// Pure Dart — zero Flutter/state imports.
abstract final class TerrainBonus {
  /// Returns the modified damage output for [count] units of [role] in [context].
  ///
  /// Applied bonuses:
  /// - **Knight Road Charge**: ×2 damage when [BattleContext.isOnRoad] is true.
  /// - **Archer High Ground**: ×2 damage when defending castle and [BattleContext.highGroundActive].
  static int applyBonus({
    required UnitRole role,
    required int count,
    required BattleContext context,
  }) {
    final baseDamage = role.damage * count;

    // Knight road charge: 2× on road
    if (role == UnitRole.knight && context.isOnRoad) {
      return baseDamage * 2;
    }

    // Archer high ground: 2× when defending castle and high ground active
    if (role == UnitRole.archer &&
        context.isDefendingCastle &&
        context.highGroundActive) {
      return baseDamage * 2;
    }

    return baseDamage;
  }

  /// Returns the effective incoming damage after applying terrain-based damage reduction.
  ///
  /// - **Archer High Ground**: 75% DR → effective = floor(incoming × 0.25)
  static int applyDamageReduction({
    required int incomingDamage,
    required BattleContext context,
  }) {
    if (context.isDefendingCastle && context.highGroundActive) {
      // 75% damage reduction — only 25% passes through
      return (incomingDamage * 0.25).floor();
    }
    return incomingDamage;
  }

  /// Returns true when the Archer High Ground bonus should be active.
  ///
  /// High Ground is active when **none** of the attackers have Warriors.
  static bool highGroundActive({required List<Company> attackers}) {
    for (final co in attackers) {
      final warriors = co.composition[UnitRole.warrior] ?? 0;
      if (warriors > 0) return false;
    }
    return true;
  }

  /// Applies the Catapult Wall Breaker ability: if any attacker Company contains
  /// at least one Catapult, sets [Battle.highGroundActive] to false.
  ///
  /// Returns the updated [Battle]. Idempotent — calling repeatedly is safe.
  static Battle applyWallBreaker(Battle battle) {
    // Check if any attacker Company has Catapults
    final hasCatapult = battle.attackers.any(
      (co) => (co.composition[UnitRole.catapult] ?? 0) > 0,
    );

    if (!hasCatapult) return battle; // No wall breaker present

    if (!battle.highGroundActive) return battle; // Already negated

    return battle.copyWith(highGroundActive: false);
  }
}
