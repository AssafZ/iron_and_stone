import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/ai_controller.dart';
import 'package:iron_and_stone/domain/rules/victory_checker.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/deploy_company.dart';

// Re-export MatchOutcome so existing importers of tick_match.dart are unaffected.
export 'package:iron_and_stone/domain/rules/victory_checker.dart'
    show MatchOutcome;

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
/// 1. Reinforce stationed [CompanyOnMap]s by growing soldiers directly (no garrison).
/// 2. Advance all [CompanyOnMap] positions via [_advanceCompanies].
/// 3. Run [AiController.decide] and apply the resulting [AiAction].
/// 4. Run [CheckCollisions] to detect [BattleTrigger]s.
/// 5. Run [_checkVictory] to detect [MatchOutcome].
final class TickMatch {
  static const double _tickSeconds = 10.0;

  /// Unique ID counter shared across ticks (simple ascending integer).
  static int _aiCompanyCounter = 0;

  const TickMatch();

  /// Execute one game tick and return the resulting [TickResult].
  TickResult tick({
    required Match match,
    required List<Castle> castles,
    required List<CompanyOnMap> companies,
  }) {
    // 1. Reinforce companies stationed at a castle by growing soldiers directly.
    // Castles have no garrison pool — soldiers grow in place within companies.
    var updatedCastles = List<Castle>.from(castles);
    final reinforceResult = _reinforceStationedCompanies(
      companies: companies,
      castles: updatedCastles,
    );
    var updatedCompanies = reinforceResult.$1;
    updatedCastles = reinforceResult.$2;

    // 3. Advance company positions
    updatedCompanies = _advanceCompanies(updatedCompanies, match);

    // 4. AI decision and application
    final aiAction = const AiController().decide(
      map: match.map,
      castles: updatedCastles,
      companies: updatedCompanies,
    );

    final aiResult = _applyAiAction(
      action: aiAction,
      castles: updatedCastles,
      companies: updatedCompanies,
      match: match,
    );
    updatedCastles = aiResult.$1;
    updatedCompanies = aiResult.$2;

    // 5. Detect collisions
    final triggers = const CheckCollisions().check(
      map: match.map,
      companies: updatedCompanies,
    );

    // 6. Victory check
    final outcome = _checkVictory(updatedCastles);

    return TickResult(
      castles: updatedCastles,
      companies: updatedCompanies,
      battleTriggers: triggers,
      matchOutcome: outcome,
    );
  }

  // ---------------------------------------------------------------------------
  // AI action application
  // ---------------------------------------------------------------------------

  /// Apply [action] to the current match state, returning updated castles and
  /// companies. Pure Dart — no state-layer imports.
  (List<Castle>, List<CompanyOnMap>) _applyAiAction({
    required AiAction action,
    required List<Castle> castles,
    required List<CompanyOnMap> companies,
    required Match match,
  }) {
    switch (action) {
      case DeployAction(:final castleId, :final composition):
        final castleIdx = castles.indexWhere((c) => c.id == castleId);
        if (castleIdx < 0) return (castles, companies);

        final castle = castles[castleIdx];
        final castleNode = match.map.nodes
            .whereType<CastleNode>()
            .where((n) => n.id == castleId)
            .firstOrNull;
        if (castleNode == null) return (castles, companies);

        // Validate that garrison has enough units.
        final canDeploy = composition.entries.every(
          (e) => (castle.garrison[e.key] ?? 0) >= e.value,
        );
        if (!canDeploy) return (castles, companies);

        final companyId = 'ai_co${_aiCompanyCounter++}';
        final deployResult = const DeployCompany().deploy(
          castle: castle,
          composition: composition,
          castleNode: castleNode,
          map: match.map,
          companyId: companyId,
        );

        final newCastles = List<Castle>.from(castles);
        newCastles[castleIdx] = deployResult.updatedCastle;

        final newCompanies = List<CompanyOnMap>.from(companies)
          ..add(deployResult.company);

        return (newCastles, newCompanies);

      case MoveAction(:final companyId, :final destination):
        final idx = companies.indexWhere((c) => c.id == companyId);
        if (idx < 0) return (castles, companies);

        final updated = companies[idx].copyWith(destination: destination);
        final newCompanies = List<CompanyOnMap>.from(companies)..[idx] = updated;
        return (castles, newCompanies);

      case NoAction():
        return (castles, companies);
    }
  }

  // ---------------------------------------------------------------------------
  // Stationed-company reinforcement
  // ---------------------------------------------------------------------------

  /// Reinforce companies that are stationed at a castle (no destination) by
  /// growing their soldier counts directly (no garrison pool).
  ///
  /// Rules enforced:
  /// 1. Only companies with no [CompanyOnMap.destination] whose
  ///    [CompanyOnMap.currentNode] is a castle node are reinforced.
  /// 2. Each company's total soldiers are capped at 50.
  /// 3. Only roles **already present** (count > 0) in the company grow.
  /// 4. When the combined soldier total of ALL stationed companies at a castle
  ///    equals or exceeds [Castle.effectiveCap], growth halts for every
  ///    company at that castle.
  /// 5. The growth-rate multiplier is derived from the peasant count inside
  ///    each company (not from the garrison).
  (List<CompanyOnMap>, List<Castle>) _reinforceStationedCompanies({
    required List<CompanyOnMap> companies,
    required List<Castle> castles,
  }) {
    // Index castle nodes for fast lookup.
    final castleIds = {for (final c in castles) c.id};

    // Compute combined stationed-company soldier total per castle.
    final stationedTotals = <String, int>{};
    for (final co in companies) {
      if (co.destination != null) continue;
      if (!castleIds.contains(co.currentNode.id)) continue;
      stationedTotals[co.currentNode.id] =
          (stationedTotals[co.currentNode.id] ?? 0) +
              co.company.totalSoldiers.value;
    }

    final updatedCompanies = companies.map((co) {
      // Requirement 1: only stationary companies at a castle.
      if (co.destination != null) return co;
      if (!castleIds.contains(co.currentNode.id)) return co;

      final castle = castles.firstWhere((c) => c.id == co.currentNode.id);

      // Requirement 4: halt growth when combined stationed total ≥ effectiveCap.
      final combinedTotal = stationedTotals[castle.id] ?? 0;
      if (combinedTotal >= castle.effectiveCap) return co;

      // Requirement 5: growth rate scaled by peasant count inside this company.
      final peasants = co.company.composition[UnitRole.peasant] ?? 0;
      final multiplier = 1.0 + 0.05 * peasants;

      final currentComposition =
          Map<UnitRole, int>.from(co.company.composition);
      int companySoldiers = co.company.totalSoldiers.value;
      int castleCapRemaining = castle.effectiveCap - combinedTotal;

      // Per-role fractional accumulator: carry remainder between ticks.
      final newRemainder =
          Map<UnitRole, double>.from(co.growthRemainder);

      for (final role in UnitRole.values) {
        if (companySoldiers >= 50) break; // Requirement 2: company cap
        if (castleCapRemaining <= 0) break; // Requirement 4: castle cap

        final inCompany = currentComposition[role] ?? 0;
        // Requirement 3: only grow roles already present.
        if (inCompany <= 0) continue;
        if (inCompany >= 50) continue; // per-role slot full

        // Accumulate fractional growth this tick; slower roles carry remainder.
        final accumulated =
            (newRemainder[role] ?? 0.0) + multiplier * role.growthRate;
        final toAdd = accumulated.floor();
        newRemainder[role] = accumulated - toAdd; // carry fractional part

        if (toAdd <= 0) continue;

        final companySpace = (50 - companySoldiers).clamp(0, 50);
        final roleSpace = (50 - inCompany).clamp(0, 50);
        final canAdd = toAdd
            .clamp(0, roleSpace)
            .clamp(0, companySpace)
            .clamp(0, castleCapRemaining);
        if (canAdd <= 0) continue;

        currentComposition[role] = inCompany + canAdd;
        companySoldiers += canAdd;
        castleCapRemaining -= canAdd;
        stationedTotals[castle.id] =
            (stationedTotals[castle.id] ?? 0) + canAdd;
      }

      // Always persist the updated remainder even if no soldiers were added
      // (fraction may have changed for slow-growing roles).
      final soldierCountChanged =
          companySoldiers != co.company.totalSoldiers.value;
      if (!soldierCountChanged &&
          _remaindersEqual(co.growthRemainder, newRemainder)) {
        return co;
      }
      return co.copyWith(
        company: soldierCountChanged
            ? co.company.copyWith(composition: currentComposition)
            : co.company,
        growthRemainder: newRemainder,
      );
    }).toList();

    // Castles have no garrison to update — return them unchanged.
    return (updatedCompanies, castles);
  }

  /// Returns true when [a] and [b] have identical keys and values,
  /// used to avoid unnecessary [CompanyOnMap] copies when only the
  /// [growthRemainder] might have changed.
  bool _remaindersEqual(
    Map<UnitRole, double> a,
    Map<UnitRole, double> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Castle growth
  // ---------------------------------------------------------------------------

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
  // Victory check — delegates to VictoryChecker domain rule
  // ---------------------------------------------------------------------------

  MatchOutcome? _checkVictory(List<Castle> castles) =>
      const VictoryChecker().check(castles);
}
