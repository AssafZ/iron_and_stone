import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/rules/battle_engine.dart';

/// Use case: advance an [ActiveBattle] by exactly one round.
///
/// If the battle is already resolved ([battle.outcome] != null), the
/// [ActiveBattle] is returned unchanged.
///
/// Pure Dart — zero Flutter/state imports.
final class AdvanceBattle {
  const AdvanceBattle();

  /// Resolve one round of [activeBattle] and return the updated [ActiveBattle].
  ///
  /// If [activeBattle.battle.outcome] is already set, the same [activeBattle]
  /// is returned without modification.
  ActiveBattle advance(ActiveBattle activeBattle) {
    if (activeBattle.battle.outcome != null) {
      return activeBattle;
    }
    final roundResult =
        const BattleEngine().resolveRound(activeBattle.battle);
    return activeBattle.copyWith(battle: roundResult.updatedBattle);
  }
}
