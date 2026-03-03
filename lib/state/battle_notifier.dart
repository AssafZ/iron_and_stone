import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/rules/battle_engine.dart';
import 'package:iron_and_stone/domain/use_cases/resolve_battle.dart';

/// State held by [BattleNotifier].
final class BattleState {
  /// The current (in-progress or resolved) battle.
  final Battle battle;

  /// Non-null once the battle is fully resolved.
  final BattleResult? result;

  const BattleState({required this.battle, this.result});

  BattleState copyWith({Battle? battle, BattleResult? result}) => BattleState(
        battle: battle ?? this.battle,
        result: result ?? this.result,
      );
}

/// Riverpod notifier that drives one Battle session.
///
/// Usage:
/// ```dart
/// battleNotifierProvider.overrideWith(() => BattleNotifier()..initWithBattle(battle))
/// ```
final class BattleNotifier extends Notifier<BattleState> {
  static const _engine = BattleEngine();

  /// Initialise before the provider is first read.
  /// Must be called synchronously in `overrideWith` factories.
  Battle? _initialBattle;

  // ignore: use_setters_to_change_properties
  void initWithBattle(Battle battle) {
    _initialBattle = battle;
  }

  @override
  BattleState build() {
    final initial = _initialBattle ??
        Battle(
          attackers: [],
          defenders: [],
        );
    return BattleState(battle: initial);
  }

  /// Advance the battle by one round.
  ///
  /// If the battle is already resolved, this is a no-op.
  void advanceRound() {
    final current = state;
    if (current.battle.outcome != null) return; // already resolved

    final roundResult = _engine.resolveRound(current.battle);
    final updated = roundResult.updatedBattle;

    if (updated.outcome != null) {
      // Battle resolved — extract full result
      // We can't easily call resolve() here since we're mid-session;
      // extract survivors from the final battle state directly.
      final attackerSurvivors = updated.attackers
          .where((c) => c.totalSoldiers.value > 0)
          .toList();
      final defenderSurvivors = updated.defenders
          .where((c) => c.totalSoldiers.value > 0)
          .toList();

      final result = BattleResult(
        outcome: updated.outcome!,
        attackerSurvivors: attackerSurvivors,
        defenderSurvivors: defenderSurvivors,
        finalBattle: updated,
        castleOwnershipTransfer: null,
      );

      state = BattleState(battle: updated, result: result);
    } else {
      state = BattleState(battle: updated);
    }
  }
}

/// Global provider for the active battle session.
final battleNotifierProvider =
    NotifierProvider<BattleNotifier, BattleState>(BattleNotifier.new);
