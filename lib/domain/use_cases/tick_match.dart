import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// The outcome of a completed match.
enum MatchOutcome {
  /// Human player controls all castles.
  playerWins,

  /// AI controls all castles.
  aiWins,
}

/// The immutable result of a single game-loop tick.
final class TickResult {
  final List<Castle> castles;
  final List<CompanyOnMap> companies;
  final List<BattleTrigger> battleTriggers;

  /// Non-null when a [MatchOutcome] has been determined this tick.
  final MatchOutcome? matchOutcome;

  const TickResult({
    required this.castles,
    required this.companies,
    required this.battleTriggers,
    this.matchOutcome,
  });
}

/// Per-tick orchestrator (pure Dart, zero Flutter/state imports).
///
/// Execution order per tick:
/// 1. Apply [_tickCastleGrowth] to all castles.
/// 2. Advance all [CompanyOnMap] positions via [_advanceCompanies].
/// 3. Run [CheckCollisions] to detect [BattleTrigger]s.
/// 4. Run [_checkVictory] to detect [MatchOutcome].
///
/// AI decisions are intentionally delegated to a future `AiController` use
/// case and are not wired here yet (added in Phase 7).
final class TickMatch {
  static const double _tickSeconds = 10.0;

  // Growth rate: 1 unit per role per tick at base multiplier.
  static const int _baseGrowthPerTick = 1;

  const TickMatch();

  /// Execute one game tick and return the resulting [TickResult].
  TickResult tick({
    required Match match,
    required List<Castle> castles,
    required List<CompanyOnMap> companies,
  }) {
    // 1. Castle growth
    final updatedCastles = castles.map(_tickCastleGrowth).toList();

    // 2. Advance company positions
    final updatedCompanies = _advanceCompanies(companies, match);

    // 3. Detect collisions
    final triggers = const CheckCollisions().check(
      map: match.map,
      companies: updatedCompanies,
    );

    // 4. Victory check
    final outcome = _checkVictory(updatedCastles);

    return TickResult(
      castles: updatedCastles,
      companies: updatedCompanies,
      battleTriggers: triggers,
      matchOutcome: outcome,
    );
  }

  // ---------------------------------------------------------------------------
  // Castle growth
  // ---------------------------------------------------------------------------

  Castle _tickCastleGrowth(Castle castle) {
    if (_totalGarrison(castle) >= castle.effectiveCap) {
      return castle; // at cap — no growth
    }

    final multiplier = castle.growthRateMultiplier;
    final updated = Map<UnitRole, int>.from(castle.garrison);

    for (final role in UnitRole.values) {
      final current = updated[role] ?? 0;
      if (current >= 50) continue; // per-role slot cap
      final growth = (_baseGrowthPerTick * multiplier).floor();
      updated[role] = current + (growth < 1 ? 1 : growth);
    }

    return castle.copyWith(garrison: updated);
  }

  static int _totalGarrison(Castle castle) =>
      castle.garrison.values.fold(0, (sum, v) => sum + v);

  // ---------------------------------------------------------------------------
  // Company movement
  // ---------------------------------------------------------------------------

  List<CompanyOnMap> _advanceCompanies(
    List<CompanyOnMap> companies,
    Match match,
  ) {
    return companies.map((co) => _advance(co, match)).toList();
  }

  CompanyOnMap _advance(CompanyOnMap co, Match match) {
    if (co.destination == null || co.destination!.id == co.currentNode.id) {
      return co; // stationary or already arrived
    }

    // Find the next node along the path toward the destination.
    final path = match.map.pathBetween(co.currentNode, co.destination!);
    if (path.length < 2) return co; // no valid path

    final nextNode = path[1];

    // Find edge length for the current segment
    final edge = match.map.edges.firstWhere(
      (e) => e.from.id == co.currentNode.id && e.to.id == nextNode.id,
      orElse: () => throw StateError(
        'No edge from ${co.currentNode.id} to ${nextNode.id}',
      ),
    );

    // Advance progress by speed units per tick / edge length
    final speedPerTick = co.company.movementSpeed.toDouble();
    final newProgress = co.progress + (speedPerTick * _tickSeconds) / edge.length;

    if (newProgress >= 1.0) {
      // Arrived at next node — recurse for remaining progress if needed
      return co.copyWith(
        currentNode: nextNode,
        destination: co.destination,
        progress: 0.0,
      );
    }

    return co.copyWith(progress: newProgress);
  }

  // ---------------------------------------------------------------------------
  // Victory check
  // ---------------------------------------------------------------------------

  MatchOutcome? _checkVictory(List<Castle> castles) {
    if (castles.isEmpty) return null;

    final allPlayer = castles.every((c) => c.ownership == Ownership.player);
    if (allPlayer) return MatchOutcome.playerWins;

    final allAi = castles.every((c) => c.ownership == Ownership.ai);
    if (allAi) return MatchOutcome.aiWins;

    return null;
  }
}
