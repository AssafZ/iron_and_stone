import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// The lifecycle phase of a [Match].
enum MatchPhase {
  /// Match is being set up (map generation, garrison seeding).
  setup,

  /// Match is in progress.
  playing,

  /// Match has ended (Total Conquest achieved).
  ended,

  /// Match is paused mid-battle.
  inBattle,
}

/// The win condition variant. MVP only supports [totalConquest].
enum WinCondition {
  /// One player controls all castles.
  totalConquest,
}

/// A single-player match session.
///
/// Holds the [map], the [humanPlayer] ownership identity, elapsed game time,
/// and the current [phase]. The AI is always the counterpart ownership.
final class Match {
  final GameMap map;

  /// The [Ownership] value assigned to the human player.
  /// Must be [Ownership.player] or [Ownership.ai] — never [Ownership.neutral].
  final Ownership humanPlayer;

  /// Total time elapsed since match start.
  final Duration elapsedTime;

  /// Current lifecycle phase.
  final MatchPhase phase;

  /// The win condition for this match (always [WinCondition.totalConquest] in MVP).
  WinCondition get winCondition => WinCondition.totalConquest;

  Match({
    required this.map,
    required this.humanPlayer,
    required this.phase,
    this.elapsedTime = Duration.zero,
  }) {
    if (humanPlayer == Ownership.neutral) {
      throw ArgumentError(
        'humanPlayer must be Ownership.player or Ownership.ai, not Ownership.neutral.',
      );
    }
  }

  /// Returns a new [Match] with updated fields.
  Match copyWith({
    GameMap? map,
    Ownership? humanPlayer,
    Duration? elapsedTime,
    MatchPhase? phase,
  }) {
    return Match(
      map: map ?? this.map,
      humanPlayer: humanPlayer ?? this.humanPlayer,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      phase: phase ?? this.phase,
    );
  }

  @override
  String toString() =>
      'Match(player=$humanPlayer, phase=$phase, elapsed=$elapsedTime)';
}
