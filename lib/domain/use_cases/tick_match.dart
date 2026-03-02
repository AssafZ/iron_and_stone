import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/rules/ai_controller.dart';
import 'package:iron_and_stone/domain/rules/victory_checker.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/deploy_company.dart';
import 'package:iron_and_stone/domain/use_cases/tick_castle_growth.dart';

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
/// 1. Apply [TickCastleGrowth] to all castles.
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
    // 1. Castle growth — delegated to TickCastleGrowth use case.
    var updatedCastles = castles.map(const TickCastleGrowth().tick).toList();

    // 2. Advance company positions
    var updatedCompanies = _advanceCompanies(companies, match);

    // 3. AI decision and application
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

    // 4. Detect collisions
    final triggers = const CheckCollisions().check(
      map: match.map,
      companies: updatedCompanies,
    );

    // 5. Victory check
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
