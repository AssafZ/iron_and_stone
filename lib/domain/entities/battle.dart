import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';

/// The outcome of a fully resolved battle.
enum BattleOutcome {
  /// Attacking side won; defenders eliminated.
  attackersWin,

  /// Defending side won; attackers eliminated.
  defendersWin,

  /// Both sides eliminated simultaneously — no castle ownership transfer.
  draw,
}

/// Whether the battle is taking place on a road or at a castle.
enum BattleKind {
  /// Road collision — Knight road charge applies.
  roadCollision,

  /// Castle assault — Archer High Ground may apply.
  castleAssault,
}

/// HP tracking for a side in a battle.
/// Maps each soldier slot (role + index) to remaining HP.
/// Key format: "${role.name}_$index"
typedef SideHp = Map<String, int>;

/// An active or completed battle between two sets of [Company]s.
///
/// [attackers] and [defenders] must each be non-empty at construction time.
/// [roundNumber] starts at 0 and increments with each resolved round.
/// [outcome] is null until the battle is fully resolved.
/// [highGroundActive] tracks whether Archer High Ground bonus is still in effect.
///
/// HP is tracked per-unit across rounds via [attackerHp] and [defenderHp].
/// If null, the engine initialises HP from [UnitRole.hp] on round 1.
///
/// [initialAttackers] and [initialDefenders] capture the starting compositions
/// at round 0 (before any fighting). They are set once at creation time and
/// preserved unchanged through [copyWith] — used by the battle summary screen
/// to display initial vs. final troop counts per role.
final class Battle {
  final List<Company> attackers;
  final List<Company> defenders;

  /// Current round index (0 = not yet started).
  final int roundNumber;

  /// Chronological log of round summaries.
  final List<String> roundLog;

  /// Null until the battle is resolved.
  final BattleOutcome? outcome;

  /// Whether the Archer High Ground bonus is currently active.
  final bool highGroundActive;

  /// The kind of terrain this battle is taking place on.
  final BattleKind kind;

  /// Per-unit remaining HP for the attacking side.
  final SideHp? attackerHp;

  /// Per-unit remaining HP for the defending side.
  final SideHp? defenderHp;

  /// The attacker companies as they were at the very start of the battle
  /// (round 0, before any fighting). Preserved through [copyWith].
  /// Null only for battles created before this field was introduced.
  final List<Company>? initialAttackers;

  /// The defender companies as they were at the very start of the battle
  /// (round 0, before any fighting). Preserved through [copyWith].
  /// Null only for battles created before this field was introduced.
  final List<Company>? initialDefenders;

  Battle({
    required List<Company> attackers,
    required List<Company> defenders,
    this.roundNumber = 0,
    List<String>? roundLog,
    this.outcome,
    this.highGroundActive = false,
    this.kind = BattleKind.roadCollision,
    this.attackerHp,
    this.defenderHp,
    List<Company>? initialAttackers,
    List<Company>? initialDefenders,
  })  : attackers = List.unmodifiable(attackers),
        defenders = List.unmodifiable(defenders),
        roundLog = List.unmodifiable(roundLog ?? const []),
        initialAttackers =
            initialAttackers != null ? List.unmodifiable(initialAttackers) : null,
        initialDefenders =
            initialDefenders != null ? List.unmodifiable(initialDefenders) : null {
    if (attackers.isEmpty) {
      throw ArgumentError('Battle must have at least one attacker Company.');
    }
    if (defenders.isEmpty) {
      throw ArgumentError('Battle must have at least one defender Company.');
    }
  }

  /// Returns a new [Battle] with updated fields.
  ///
  /// [initialAttackers] and [initialDefenders] are intentionally NOT
  /// overridable here — they must stay fixed after construction.
  Battle copyWith({
    List<Company>? attackers,
    List<Company>? defenders,
    int? roundNumber,
    List<String>? roundLog,
    BattleOutcome? outcome,
    bool? highGroundActive,
    BattleKind? kind,
    SideHp? attackerHp,
    SideHp? defenderHp,
  }) {
    return Battle(
      attackers: attackers ?? this.attackers,
      defenders: defenders ?? this.defenders,
      roundNumber: roundNumber ?? this.roundNumber,
      roundLog: roundLog ?? this.roundLog,
      outcome: outcome ?? this.outcome,
      highGroundActive: highGroundActive ?? this.highGroundActive,
      kind: kind ?? this.kind,
      attackerHp: attackerHp ?? this.attackerHp,
      defenderHp: defenderHp ?? this.defenderHp,
      // Always carry forward the initial snapshot unchanged.
      initialAttackers: initialAttackers,
      initialDefenders: initialDefenders,
    );
  }

  @override
  String toString() =>
      'Battle(round=$roundNumber, attackers=${attackers.length}, '
      'defenders=${defenders.length}, outcome=$outcome, '
      'kind=$kind, highGround=$highGroundActive)';
}

/// Build a flat HP map for a list of Companies.
/// Key: "${role.name}_$index" (melee-first ordering for determinism).
SideHp buildHpMap(List<Company> companies) {
  final hp = <String, int>{};
  var index = 0;
  for (final co in companies) {
    final sorted = co.composition.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => a.key.range.compareTo(b.key.range));
    for (final entry in sorted) {
      for (var i = 0; i < entry.value; i++) {
        hp['${entry.key.name}_$index'] = entry.key.hp;
        index++;
      }
    }
  }
  return hp;
}
