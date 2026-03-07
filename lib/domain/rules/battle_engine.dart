import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/terrain_bonus.dart';
import 'package:iron_and_stone/domain/value_objects/soldier_count.dart';

/// The result of resolving one battle round.
final class BattleRoundResult {
  final Battle updatedBattle;
  final int roundDamageToAttackers;
  final int roundDamageToDefenders;

  const BattleRoundResult({
    required this.updatedBattle,
    required this.roundDamageToAttackers,
    required this.roundDamageToDefenders,
  });
}

/// Resolves simultaneous-round battles between two sets of [Company]s.
///
/// HP is tracked across rounds via [Battle.attackerHp] / [Battle.defenderHp].
/// Both sides deal damage simultaneously — if both reach 0 in the same round,
/// the outcome is [BattleOutcome.draw].
///
/// Pure Dart — zero Flutter/state imports.
final class BattleEngine {
  const BattleEngine();

  BattleRoundResult resolveRound(Battle battle) {
    // Step 1: Wall Breaker
    final Battle current = TerrainBonus.applyWallBreaker(battle);

    // Step 2: Initialise HP maps if not yet set
    final attackerHp = Map<String, int>.from(
      current.attackerHp ?? buildHpMap(current.attackers),
    );
    final defenderHp = Map<String, int>.from(
      current.defenderHp ?? buildHpMap(current.defenders),
    );

    // Rebuild Companies from HP maps to compute live soldier counts
    final liveAttackers = _companiesFromHp(current.attackers, attackerHp);
    final liveDefenders = _companiesFromHp(current.defenders, defenderHp);

    // Step 3: Build context
    final ctx = BattleContext(
      isOnRoad: current.kind == BattleKind.roadCollision,
      isDefendingCastle: current.kind == BattleKind.castleAssault,
      highGroundActive: current.highGroundActive,
    );

    // Step 4: Calculate simultaneous damage
    final attackerDmg = _totalDamage(liveAttackers, ctx);
    final defenderDmg = _totalDamage(liveDefenders, ctx);

    final dmgToDefenders =
        TerrainBonus.applyDamageReduction(incomingDamage: attackerDmg, context: ctx);
    final dmgToAttackers = defenderDmg;

    // Step 5: Apply damage to HP maps simultaneously
    _applyDamageToHp(attackerHp, dmgToAttackers);
    _applyDamageToHp(defenderHp, dmgToDefenders);

    // Step 6: Rebuild live companies from updated HP maps
    final nextAttackers = _companiesFromHp(current.attackers, attackerHp);
    final nextDefenders = _companiesFromHp(current.defenders, defenderHp);

    final attackersAlive = nextAttackers.isNotEmpty;
    final defendersAlive = nextDefenders.isNotEmpty;

    BattleOutcome? outcome;
    if (!attackersAlive && !defendersAlive) {
      outcome = BattleOutcome.draw;
    } else if (!defendersAlive) {
      outcome = BattleOutcome.attackersWin;
    } else if (!attackersAlive) {
      outcome = BattleOutcome.defendersWin;
    }

    // Step 7: Round log
    final logEntry =
        'Round ${current.roundNumber + 1}: '
        'Att dealt $attackerDmg (→$dmgToDefenders to def); '
        'Def dealt $defenderDmg to att. '
        'Survivors: att=${_count(nextAttackers)}, def=${_count(nextDefenders)}.';

    final newLog = [...current.roundLog, logEntry];

    // Placeholder companies for Battle invariant (≥1 Company per side)
    final storedAttackers = nextAttackers.isEmpty
        ? [Company(composition: {UnitRole.peasant: 0})]
        : nextAttackers;
    final storedDefenders = nextDefenders.isEmpty
        ? [Company(composition: {UnitRole.peasant: 0})]
        : nextDefenders;

    final updatedBattle = Battle(
      attackers: storedAttackers,
      defenders: storedDefenders,
      roundNumber: current.roundNumber + 1,
      roundLog: newLog,
      outcome: outcome,
      highGroundActive: current.highGroundActive,
      kind: current.kind,
      attackerHp: outcome != null ? null : attackerHp,
      defenderHp: outcome != null ? null : defenderHp,
    );

    return BattleRoundResult(
      updatedBattle: updatedBattle,
      roundDamageToAttackers: dmgToAttackers,
      roundDamageToDefenders: dmgToDefenders,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  int _totalDamage(List<Company> companies, BattleContext ctx) {
    var total = 0;
    for (final co in companies) {
      for (final entry in co.composition.entries) {
        if (entry.value <= 0) continue;
        total += TerrainBonus.applyBonus(
          role: entry.key,
          count: entry.value,
          context: ctx,
        );
      }
    }
    return total;
  }

  /// Apply [damage] to the HP map, killing units whose HP drops to ≤ 0.
  /// Melee units (range=1) take damage first (front line).
  void _applyDamageToHp(Map<String, int> hpMap, int damage) {
    if (damage <= 0) return;

    // Sort keys by unit index (they are "role_index" strings)
    // Process melee-front: sort by role range then by index
    final keys = hpMap.keys.toList()
      ..sort((a, b) {
        final roleA = _roleFromKey(a);
        final roleB = _roleFromKey(b);
        final rangeCmp = roleA.range.compareTo(roleB.range);
        if (rangeCmp != 0) return rangeCmp;
        return _indexFromKey(a).compareTo(_indexFromKey(b));
      });

    var remaining = damage;
    for (final key in keys) {
      if (remaining <= 0) break;
      final hp = hpMap[key]!;
      final newHp = hp - remaining;
      if (newHp > 0) {
        hpMap[key] = newHp;
        remaining = 0;
      } else {
        hpMap.remove(key); // unit eliminated
        remaining -= hp;
      }
    }
  }

  /// Rebuild Company list from HP map — only include roles/units still alive.
  ///
  /// Survivors are partitioned into [Company]s of at most [SoldierCount.max]
  /// (50) soldiers each, preserving the [SoldierCount] invariant even when the
  /// original side had more than 50 soldiers spread across multiple companies.
  List<Company> _companiesFromHp(
    List<Company> original,
    Map<String, int> hpMap,
  ) {
    if (hpMap.isEmpty) return const [];

    // Count surviving units per role from the HP map.
    final roleCounts = <UnitRole, int>{};
    for (final key in hpMap.keys) {
      final role = _roleFromKey(key);
      roleCounts[role] = (roleCounts[role] ?? 0) + 1;
    }
    if (roleCounts.isEmpty) return const [];

    // If total ≤ 50 we can return a single Company (common case).
    final total = roleCounts.values.fold(0, (s, n) => s + n);
    if (total <= SoldierCount.max) {
      return [Company(composition: roleCounts)];
    }

    // Otherwise split into Company-sized chunks of ≤ 50 soldiers each.
    // Fill each Company greedily, role by role (preserving proportions
    // as closely as possible while respecting per-role counts).
    final companies = <Company>[];
    final remaining = Map<UnitRole, int>.from(roleCounts);

    while (remaining.values.any((n) => n > 0)) {
      final chunk = <UnitRole, int>{};
      var slots = SoldierCount.max;

      for (final role in UnitRole.values) {
        if (slots <= 0) break;
        final available = remaining[role] ?? 0;
        if (available <= 0) continue;
        final take = available.clamp(0, slots);
        chunk[role] = take;
        remaining[role] = available - take;
        slots -= take;
      }

      if (chunk.isNotEmpty) {
        companies.add(Company(composition: chunk));
      } else {
        break; // safety: avoid infinite loop
      }
    }

    return companies;
  }

  UnitRole _roleFromKey(String key) {
    final name = key.substring(0, key.lastIndexOf('_'));
    return UnitRole.values.firstWhere((r) => r.name == name);
  }

  int _indexFromKey(String key) {
    return int.parse(key.substring(key.lastIndexOf('_') + 1));
  }

  int _count(List<Company> companies) =>
      companies.fold(0, (s, co) => s + co.totalSoldiers.value);
}
