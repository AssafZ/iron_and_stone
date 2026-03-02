import 'package:iron_and_stone/domain/entities/company.dart';

/// The outcome of a fully resolved battle.
enum BattleOutcome {
  /// Attacking side won; defenders eliminated.
  attackersWin,

  /// Defending side won; attackers eliminated.
  defendersWin,

  /// Both sides eliminated simultaneously — no castle ownership transfer.
  draw,
}

/// An active or completed battle between two sets of [Company]s.
///
/// [attackers] and [defenders] must each be non-empty at construction time.
/// [roundNumber] starts at 0 and increments with each resolved round.
/// [outcome] is null until the battle is fully resolved.
final class Battle {
  final List<Company> attackers;
  final List<Company> defenders;

  /// Current round index (0 = not yet started).
  final int roundNumber;

  /// Chronological log of round summaries.
  final List<String> roundLog;

  /// Null until the battle is resolved.
  final BattleOutcome? outcome;

  Battle({
    required List<Company> attackers,
    required List<Company> defenders,
    this.roundNumber = 0,
    List<String>? roundLog,
    this.outcome,
  })  : attackers = List.unmodifiable(attackers),
        defenders = List.unmodifiable(defenders),
        roundLog = List.unmodifiable(roundLog ?? const []) {
    if (attackers.isEmpty) {
      throw ArgumentError('Battle must have at least one attacker Company.');
    }
    if (defenders.isEmpty) {
      throw ArgumentError('Battle must have at least one defender Company.');
    }
  }

  /// Returns a new [Battle] with updated fields.
  Battle copyWith({
    List<Company>? attackers,
    List<Company>? defenders,
    int? roundNumber,
    List<String>? roundLog,
    BattleOutcome? outcome,
  }) {
    return Battle(
      attackers: attackers ?? this.attackers,
      defenders: defenders ?? this.defenders,
      roundNumber: roundNumber ?? this.roundNumber,
      roundLog: roundLog ?? this.roundLog,
      outcome: outcome ?? this.outcome,
    );
  }

  @override
  String toString() =>
      'Battle(round=$roundNumber, attackers=${attackers.length}, '
      'defenders=${defenders.length}, outcome=$outcome)';
}
