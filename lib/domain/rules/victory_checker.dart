import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// The outcome of a completed match (Total Conquest win condition).
enum MatchOutcome {
  /// Human player controls all castles.
  playerWins,

  /// AI opponent controls all castles.
  aiWins,
}

/// Pure domain rule: decides whether a match has ended via Total Conquest.
///
/// Returns [MatchOutcome.playerWins] when every [Castle] is owned by
/// [Ownership.player], [MatchOutcome.aiWins] when every [Castle] is owned by
/// [Ownership.ai], and `null` in all other cases (mixed or neutral ownership,
/// or an empty list).
///
/// This class is intentionally stateless and has a `const` constructor so it
/// can be instantiated without allocation overhead in hot paths.
final class VictoryChecker {
  const VictoryChecker();

  /// Checks [castles] for Total Conquest and returns the appropriate
  /// [MatchOutcome], or `null` if no victory condition has been met.
  MatchOutcome? check(List<Castle> castles) {
    if (castles.isEmpty) return null;

    final allPlayer = castles.every((c) => c.ownership == Ownership.player);
    if (allPlayer) return MatchOutcome.playerWins;

    final allAi = castles.every((c) => c.ownership == Ownership.ai);
    if (allAi) return MatchOutcome.aiWins;

    return null;
  }
}
