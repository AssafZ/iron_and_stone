import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/rules/battle_engine.dart';
import 'package:iron_and_stone/domain/rules/terrain_bonus.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// Identifies which side of a battle a Company belongs to.
enum BattleSide { attackers, defenders }

/// Records a castle ownership transfer resulting from a battle.
final class CastleOwnershipTransfer {
  final String castleId;
  final Ownership newOwner;

  const CastleOwnershipTransfer({
    required this.castleId,
    required this.newOwner,
  });
}

/// The complete result of a fully resolved battle.
final class BattleResult {
  final BattleOutcome outcome;
  final List<Company> attackerSurvivors;
  final List<Company> defenderSurvivors;

  /// Non-null when a castle's ownership should change (castle-assault only,
  /// attacker win only — never on draw or road collision).
  final CastleOwnershipTransfer? castleOwnershipTransfer;

  /// The fully resolved [Battle] entity for logging/display purposes.
  final Battle finalBattle;

  const BattleResult({
    required this.outcome,
    required this.attackerSurvivors,
    required this.defenderSurvivors,
    required this.finalBattle,
    this.castleOwnershipTransfer,
  });
}

/// Use case: orchestrate [BattleEngine] rounds until the battle is resolved.
///
/// Handles:
/// - Simultaneous-round resolution via [BattleEngine].
/// - Draw detection ([BattleOutcome.draw] — no ownership transfer).
/// - Reinforcement waves via [addReinforcement] (FR-021).
/// - Castle ownership transfer when defender eliminated at castle (FR-022a).
///
/// Pure Dart — zero Flutter/state imports.
final class ResolveBattle {
  static const int _maxRounds = 500; // safety cap to prevent infinite loops

  const ResolveBattle();

  /// Fully resolve [battle] and return a [BattleResult].
  ///
  /// [trigger] is used to determine if this is a castle-assault (for ownership
  /// transfer logic).
  /// [attackerOwnership] is used to assign new castle ownership on attacker win.
  BattleResult resolve({
    required Battle battle,
    required BattleTrigger trigger,
    Ownership attackerOwnership = Ownership.player,
  }) {
    final engine = const BattleEngine();

    // If castle assault, initialise high ground based on whether Warriors present
    Battle current = battle;
    if (trigger.kind == BattleTriggerKind.castleAssault) {
      final hgActive = TerrainBonus.highGroundActive(attackers: battle.attackers);
      current = battle.copyWith(
        highGroundActive: hgActive,
        kind: BattleKind.castleAssault,
      );
    } else {
      current = battle.copyWith(kind: BattleKind.roadCollision);
    }

    for (var i = 0; i < _maxRounds; i++) {
      final roundResult = engine.resolveRound(current);
      current = roundResult.updatedBattle;

      if (current.outcome != null) break;
    }

    final outcome = current.outcome ?? BattleOutcome.draw;

    // Extract real survivors (filter out placeholder empty companies)
    final attackerSurvivors = _extractSurvivors(current.attackers);
    final defenderSurvivors = _extractSurvivors(current.defenders);

    // Castle ownership transfer: only on castle-assault + attackers win (not draw)
    CastleOwnershipTransfer? transfer;
    if (trigger.kind == BattleTriggerKind.castleAssault &&
        outcome == BattleOutcome.attackersWin &&
        trigger.location is CastleNode) {
      transfer = CastleOwnershipTransfer(
        castleId: trigger.location.id,
        newOwner: attackerOwnership,
      );
    }

    return BattleResult(
      outcome: outcome,
      attackerSurvivors: attackerSurvivors,
      defenderSurvivors: defenderSurvivors,
      finalBattle: current,
      castleOwnershipTransfer: transfer,
    );
  }

  /// Add a [reinforcement] Company to the appropriate [side] of an ongoing [battle].
  ///
  /// Returns the updated [Battle].
  static Battle addReinforcement({
    required Battle battle,
    required Company reinforcement,
    required BattleSide side,
  }) {
    if (side == BattleSide.attackers) {
      return battle.copyWith(
        attackers: [...battle.attackers, reinforcement],
      );
    } else {
      return battle.copyWith(
        defenders: [...battle.defenders, reinforcement],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Extract Companies with at least 1 survivor (filter out empty placeholders).
  List<Company> _extractSurvivors(List<Company> companies) {
    return companies
        .where((co) => co.totalSoldiers.value > 0)
        .toList();
  }
}
