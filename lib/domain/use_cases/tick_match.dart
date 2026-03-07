import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/ai_controller.dart';
import 'package:iron_and_stone/domain/rules/movement_rules.dart';
import 'package:iron_and_stone/domain/rules/victory_checker.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/deploy_company.dart';
import 'package:iron_and_stone/domain/use_cases/merge_companies.dart';
import 'package:iron_and_stone/domain/use_cases/move_company.dart';
import 'package:iron_and_stone/domain/use_cases/resolve_battle.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';

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

  /// The list of [ActiveBattle]s after this tick (new + ongoing; resolved removed).
  final List<ActiveBattle> activeBattles;

  const TickResult({
    required this.castles,
    required this.companies,
    required this.battleTriggers,
    this.matchOutcome,
    this.activeBattles = const [],
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
    required List<ActiveBattle> activeBattles,
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

    // 2. Proximity merge: update initiator destinations to track targets,
    //    then resolve co-located merges and cancellations.
    updatedCompanies = _updateProximityMergeDestinations(updatedCompanies, match);
    updatedCompanies = _resolveProximityMerges(updatedCompanies, match);

    // 3. Advance company positions (frozen companies are skipped inside _advance)
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
    // Pass the live castle ownership map so CheckCollisions uses up-to-date
    // owners (not the stale static CastleNode.ownership from match.map).
    final liveCastleOwnership = {
      for (final c in updatedCastles) c.id: c.ownership,
    };
    final triggers = const CheckCollisions().check(
      map: match.map,
      companies: updatedCompanies,
      castleOwnership: liveCastleOwnership,
    );

    // ---------------------------------------------------------------------------
    // Empty-castle capture: a company NOT in a battle at an enemy castle with
    // no garrison transfers ownership immediately (FR-004 / T026).
    // ---------------------------------------------------------------------------
    for (final co in updatedCompanies) {
      if (co.battleId != null) continue; // skip companies already in a battle
      final node = co.currentNode;
      if (node is! CastleNode) continue;
      if (!CheckCollisions.isEnemy(co.ownership, node.ownership)) continue;

      // Check for living garrison (stationary companies at the castle belonging to its owner)
      final hasLivingGarrison = updatedCompanies.any((c) {
        if (c.currentNode.id != node.id) return false;
        if (c.ownership != node.ownership) return false;
        final isStationary = c.destination == null || c.destination!.id == c.currentNode.id;
        return isStationary && c.company.totalSoldiers.value > 0;
      });

      if (!hasLivingGarrison) {
        // Transfer castle ownership immediately — find and update the castle.
        final castleIdx = updatedCastles.indexWhere((c) => c.id == node.id);
        if (castleIdx >= 0) {
          updatedCastles = List<Castle>.from(updatedCastles)
            ..[castleIdx] = updatedCastles[castleIdx].copyWith(ownership: co.ownership);
        }
      }
    }

    // ---------------------------------------------------------------------------
    // Phase A: process new battle triggers — create ActiveBattles + tag companies
    // ---------------------------------------------------------------------------
    var currentActiveBattles = List<ActiveBattle>.from(activeBattles);
    final existingBattleNodeIds = {for (final b in currentActiveBattles) b.nodeId};
    // Track battles created this tick so Phase A-R skips them — reinforcements
    // shouldn't be added to a battle in the same tick it was created.
    final newBattleIds = <String>{};

    for (final trigger in triggers) {
      final nodeId = trigger.location.id;

      // Reinforcement: if a battle already exists at this node, add any new
      // companies (not yet in the battle) as reinforcements on the appropriate side.
      if (existingBattleNodeIds.contains(nodeId)) {
        final battleIdx = currentActiveBattles.indexWhere((b) => b.nodeId == nodeId);
        if (battleIdx < 0) continue;
        var ab = currentActiveBattles[battleIdx];

        // Find companies at this node that do NOT yet have a battleId.
        final newArrivals = updatedCompanies.where((c) {
          if (c.currentNode.id != nodeId) return false;
          if (c.battleId == ab.id) return false; // already in battle
          if (c.battleId != null) return false;   // in a different battle
          return true;
        }).toList();

        for (final newCo in newArrivals) {
          // Determine side: attacker if ownership matches attackerOwnership, else defender.
          final side = newCo.ownership == ab.attackerOwnership
              ? BattleSide.attackers
              : BattleSide.defenders;

          final updatedBattle = ResolveBattle.addReinforcement(
            battle: ab.battle,
            reinforcement: newCo.company,
            side: side,
          );

          final newAttackerIds = side == BattleSide.attackers
              ? [...ab.attackerCompanyIds, newCo.id]
              : ab.attackerCompanyIds.toList();
          final newDefenderIds = side == BattleSide.defenders
              ? [...ab.defenderCompanyIds, newCo.id]
              : ab.defenderCompanyIds.toList();

          ab = ActiveBattle(
            nodeId: ab.nodeId,
            attackerCompanyIds: newAttackerIds,
            defenderCompanyIds: newDefenderIds,
            attackerOwnership: ab.attackerOwnership,
            battle: updatedBattle,
          );
        }

        currentActiveBattles[battleIdx] = ab;

        // Tag new arrivals with the battleId.
        final battleId = ab.id;
        if (newArrivals.isNotEmpty) {
          final newArrivalIds = newArrivals.map((c) => c.id).toSet();
          updatedCompanies = [
            for (final co in updatedCompanies)
              if (newArrivalIds.contains(co.id))
                co.copyWith(battleId: battleId)
              else
                co,
          ];
        }
        continue;
      }

      // New battle — partition companies into attacker/defender sides.
      final involvedCompanies = updatedCompanies
          .where((c) => trigger.companyIds.contains(c.id))
          .toList();

      // For castleAssault: the castle owner's companies are defenders; attackers are enemies.
      // For roadCollision: pick first ownership as attackers.
      final Ownership attackerOwnership;
      final List<String> attackerIds;
      final List<String> defenderIds;

      if (trigger.kind == BattleTriggerKind.castleAssault &&
          trigger.location is CastleNode) {
        final castleNode = trigger.location as CastleNode;
        // Attackers = companies that are enemies of the castle owner
        final attackers = involvedCompanies
            .where((c) => CheckCollisions.isEnemy(c.ownership, castleNode.ownership))
            .toList();
        final defenders = involvedCompanies
            .where((c) => c.ownership == castleNode.ownership)
            .toList();

        if (attackers.isEmpty || defenders.isEmpty) continue;

        attackerOwnership = attackers.first.ownership;
        attackerIds = attackers.map((c) => c.id).toList();
        defenderIds = defenders.map((c) => c.id).toList();
      } else {
        // roadCollision
        final ownerships = involvedCompanies.map((c) => c.ownership).toSet();
        attackerOwnership = ownerships.first;
        attackerIds = involvedCompanies
            .where((c) => c.ownership == attackerOwnership)
            .map((c) => c.id)
            .toList();
        defenderIds = involvedCompanies
            .where((c) => !attackerIds.contains(c.id))
            .map((c) => c.id)
            .toList();
      }

      final attackerCompanies = involvedCompanies
          .where((c) => attackerIds.contains(c.id))
          .map((c) => c.company)
          .toList();
      final defenderCompanies = involvedCompanies
          .where((c) => defenderIds.contains(c.id))
          .map((c) => c.company)
          .toList();

      // Ensure both sides are non-empty (safety guard).
      if (attackerCompanies.isEmpty || defenderCompanies.isEmpty) continue;

      final newBattle = ActiveBattle(
        nodeId: nodeId,
        attackerCompanyIds: attackerIds,
        defenderCompanyIds: defenderIds,
        attackerOwnership: attackerOwnership,
        midRoadProgress: trigger.midRoadProgress,
        battle: Battle(
          attackers: attackerCompanies,
          defenders: defenderCompanies,
          kind: trigger.kind == BattleTriggerKind.castleAssault
              ? BattleKind.castleAssault
              : BattleKind.roadCollision,
          initialAttackers: attackerCompanies,
          initialDefenders: defenderCompanies,
        ),
      );
      currentActiveBattles.add(newBattle);
      existingBattleNodeIds.add(nodeId);
      newBattleIds.add(newBattle.id); // skip in Phase A-R

      // Tag all involved companies with this battle's id.
      final battleId = newBattle.id;
      updatedCompanies = [
        for (final co in updatedCompanies)
          if (trigger.companyIds.contains(co.id))
            co.copyWith(battleId: battleId)
          else
            co,
      ];
    }

    // ---------------------------------------------------------------------------
    // Phase A-R: reinforcement sweep — assign any free company at an existing
    // battle node to that battle (independent of trigger detection).
    // This handles companies that arrived while all existing combatants already
    // have a battleId, so CheckCollisions emitted no trigger for that node.
    // ---------------------------------------------------------------------------
    for (var i = 0; i < currentActiveBattles.length; i++) {
      var ab = currentActiveBattles[i];
      if (newBattleIds.contains(ab.id)) continue; // just created this tick

      final newArrivals = updatedCompanies.where((c) {
        if (c.currentNode.id != ab.nodeId) return false;
        if (c.battleId == ab.id) return false; // already in this battle
        if (c.battleId != null) return false;   // in a different battle
        return true;
      }).toList();

      if (newArrivals.isEmpty) continue;

      for (final newCo in newArrivals) {
        final side = newCo.ownership == ab.attackerOwnership
            ? BattleSide.attackers
            : BattleSide.defenders;

        final updatedBattle = ResolveBattle.addReinforcement(
          battle: ab.battle,
          reinforcement: newCo.company,
          side: side,
        );

        final newAttackerIds = side == BattleSide.attackers
            ? [...ab.attackerCompanyIds, newCo.id]
            : ab.attackerCompanyIds.toList();
        final newDefenderIds = side == BattleSide.defenders
            ? [...ab.defenderCompanyIds, newCo.id]
            : ab.defenderCompanyIds.toList();

        ab = ActiveBattle(
          nodeId: ab.nodeId,
          attackerCompanyIds: newAttackerIds,
          defenderCompanyIds: newDefenderIds,
          attackerOwnership: ab.attackerOwnership,
          battle: updatedBattle,
        );
      }

      currentActiveBattles[i] = ab;

      final battleId = ab.id;
      final newArrivalIds = newArrivals.map((c) => c.id).toSet();
      updatedCompanies = [
        for (final co in updatedCompanies)
          if (newArrivalIds.contains(co.id))
            co.copyWith(battleId: battleId)
          else
            co,
      ];
    }

    // ---------------------------------------------------------------------------
    // Phase B: intentionally removed.
    //
    // Battles are NOT auto-advanced by the game-loop tick. They are advanced
    // exclusively via MatchNotifier.advanceBattleRound() (the "Next Round"
    // button on BattleScreen). This ensures:
    //   1. The BattleIndicator is always visible for at least one tick.
    //   2. The game loop never races against the player's manual round taps.
    //   3. Phase C (cleanup) below still handles any battles that arrive
    //      already-resolved (e.g. from a direct advanceBattleRound call that
    //      resolved the battle and stored it back via MatchState).
    // ---------------------------------------------------------------------------

    // ---------------------------------------------------------------------------
    // Phase C: post-battle cleanup for resolved ActiveBattles
    // ---------------------------------------------------------------------------
    final resolvedBattleIds = <String>{};
    for (final ab in currentActiveBattles) {
      if (ab.battle.outcome == null) continue;
      resolvedBattleIds.add(ab.id);

      final outcome = ab.battle.outcome!;

      // Castle ownership transfer for castleAssault battles.
      // Only transfer on attackersWin — never on draw or defendersWin (FR-024).
      if (ab.battle.kind == BattleKind.castleAssault &&
          outcome == BattleOutcome.attackersWin) {
        final castleIdx =
            updatedCastles.indexWhere((c) => c.id == ab.nodeId);
        if (castleIdx >= 0) {
          updatedCastles = List<Castle>.from(updatedCastles)
            ..[castleIdx] =
                updatedCastles[castleIdx].copyWith(ownership: ab.attackerOwnership);
        }
      }

      // Build maps for surviving and eliminated companies.
      // Surviving companies get their composition updated from the final Battle state.
      // Eliminated companies are zeroed out so the zero-soldier filter removes them.
      final updatedById = <String, Company>{}; // surviving: updated composition
      final eliminatedIds = <String>{};        // eliminated: will be zeroed

      if (outcome == BattleOutcome.attackersWin) {
        // Attackers survive — update their composition from final Battle.attackers
        for (final entry in ab.battle.attackers.asMap().entries) {
          if (entry.key < ab.attackerCompanyIds.length) {
            updatedById[ab.attackerCompanyIds[entry.key]] = entry.value;
          }
        }
        // Defenders are eliminated
        eliminatedIds.addAll(ab.defenderCompanyIds);
      } else if (outcome == BattleOutcome.defendersWin) {
        // Defenders survive — update their composition from final Battle.defenders
        for (final entry in ab.battle.defenders.asMap().entries) {
          if (entry.key < ab.defenderCompanyIds.length) {
            updatedById[ab.defenderCompanyIds[entry.key]] = entry.value;
          }
        }
        // Attackers are eliminated
        eliminatedIds.addAll(ab.attackerCompanyIds);
      } else {
        // Draw — both sides eliminated
        eliminatedIds.addAll(ab.attackerCompanyIds);
        eliminatedIds.addAll(ab.defenderCompanyIds);
      }

      updatedCompanies = [
        for (final co in updatedCompanies)
          if (co.battleId == ab.id)
            () {
              if (eliminatedIds.contains(co.id)) {
                // Eliminated — zero out composition so zero-soldier filter removes it.
                return co.copyWith(
                  company: Company(composition: {}),
                  battleId: null,
                );
              }
              final finalCompany = updatedById[co.id];
              if (finalCompany != null) {
                return co.copyWith(
                  company: finalCompany,
                  battleId: null,
                );
              }
              // Fallback: clear battleId without changing composition.
              return co.copyWith(battleId: null);
            }()
          else
            co,
      ];
    }

    // Remove companies with zero total soldiers after battle cleanup.
    updatedCompanies = [
      for (final co in updatedCompanies)
        if (co.company.totalSoldiers.value > 0) co,
    ];

    // Remove resolved battles from the list.
    currentActiveBattles = [
      for (final ab in currentActiveBattles)
        if (!resolvedBattleIds.contains(ab.id)) ab,
    ];

    // 6. Victory check
    final outcome = _checkVictory(updatedCastles);

    // ---------------------------------------------------------------------------
    // Debug-mode invariant: every company must be on a valid road position.
    // Either progress == 0.0 (company is exactly at a named node) or there
    // exists an outgoing edge from its currentNode (company is mid-road on a
    // known segment). This fires only in debug builds (assert is a no-op in
    // release mode) and catches any code path that would produce a floating
    // company position not backed by the road network.
    // ---------------------------------------------------------------------------
    assert(
      updatedCompanies.every((co) {
        if (co.progress == 0.0) return true;
        return match.map.edges.any((e) => e.from.id == co.currentNode.id);
      }),
      'Post-tick off-road invariant violated: at least one company has '
      'progress > 0 but its currentNode has no outgoing edge in the map.',
    );

    return TickResult(
      castles: updatedCastles,
      companies: updatedCompanies,
      battleTriggers: triggers,
      matchOutcome: outcome,
      activeBattles: List.unmodifiable(currentActiveBattles),
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
    return companies.map((co) {
      // T016: companies locked in a battle do NOT advance.
      if (co.battleId != null) return co;
      return const MoveCompany().advance(
        company: co,
        map: match.map,
        tickSeconds: _tickSeconds,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Proximity merge helpers (T039 [US6])
  // ---------------------------------------------------------------------------

  /// Derive a [RoadPosition] from [co], or null if unavailable.
  static RoadPosition? _roadPositionOf(CompanyOnMap co, Match match) {
    if (co.midRoadDestination != null) return co.midRoadDestination;
    if (co.progress == 0.0) {
      final edge =
          match.map.edges.where((e) => e.from.id == co.currentNode.id).firstOrNull;
      if (edge == null) return null;
      return RoadPosition(
        currentNodeId: co.currentNode.id,
        nextNodeId: edge.to.id,
        progress: 0.0,
      );
    }
    return null;
  }

  /// Compute the road distance between two companies.
  ///
  /// Handles the boundary case where one or both companies are at a node
  /// (progress == 0.0).  When [a] is at a node (progress == 0) and [b] is
  /// mid-road, we use [b]'s segment direction for [a] if they share the same
  /// [currentNode], avoiding the "wrong arbitrary edge" problem.
  ///
  /// Returns null when the positions cannot be determined.
  static double? _roadDistanceBetweenCompanies(
    CompanyOnMap a,
    CompanyOnMap b,
    Match match,
  ) {
    // Both at nodes (progress == 0): BFS distance between their nodes.
    if (a.progress == 0.0 && b.progress == 0.0) {
      if (a.currentNode.id == b.currentNode.id) return 0.0;
      // Use roadDistance with a synthetic same-node "segment" is not possible;
      // fall back to a forward edge for each and rely on roadDistance BFS.
      // But since both are at progress=0, distance = BFS between nodes.
      // We can compute this via roadDistance using any outgoing edges.
      final edgeA = match.map.edges
          .where((e) => e.from.id == a.currentNode.id)
          .firstOrNull;
      final edgeB = match.map.edges
          .where((e) => e.from.id == b.currentNode.id)
          .firstOrNull;
      if (edgeA == null || edgeB == null) return null;
      return match.map.roadDistance(
        RoadPosition(
          currentNodeId: a.currentNode.id,
          nextNodeId: edgeA.to.id,
          progress: 0.0,
        ),
        RoadPosition(
          currentNodeId: b.currentNode.id,
          nextNodeId: edgeB.to.id,
          progress: 0.0,
        ),
      );
    }

    // [a] is at a node; [b] is mid-road — compute using b's segment for a if
    // they share the same currentNode, otherwise BFS + b's offset.
    if (a.progress == 0.0) {
      final bPos = _midRoadPositionOf(b);
      if (bPos == null) return null;
      if (a.currentNode.id == b.currentNode.id) {
        // Same node: distance = b.progress * edgeLength.
        final edge = match.map.edges
            .where((e) => e.from.id == bPos.currentNodeId && e.to.id == bPos.nextNodeId)
            .firstOrNull;
        return edge == null ? null : bPos.progress * edge.length;
      }
      // Different node: use b's nextNodeId direction for a.
      final edgeA = match.map.edges
          .where((e) => e.from.id == a.currentNode.id)
          .firstOrNull;
      if (edgeA == null) return null;
      return match.map.roadDistance(
        RoadPosition(
          currentNodeId: a.currentNode.id,
          nextNodeId: edgeA.to.id,
          progress: 0.0,
        ),
        bPos,
      );
    }

    // [b] is at a node; [a] is mid-road.
    if (b.progress == 0.0) {
      final aPos = _midRoadPositionOf(a);
      if (aPos == null) return null;
      if (b.currentNode.id == a.currentNode.id) {
        final edge = match.map.edges
            .where((e) => e.from.id == aPos.currentNodeId && e.to.id == aPos.nextNodeId)
            .firstOrNull;
        return edge == null ? null : aPos.progress * edge.length;
      }
      final edgeB = match.map.edges
          .where((e) => e.from.id == b.currentNode.id)
          .firstOrNull;
      if (edgeB == null) return null;
      return match.map.roadDistance(
        aPos,
        RoadPosition(
          currentNodeId: b.currentNode.id,
          nextNodeId: edgeB.to.id,
          progress: 0.0,
        ),
      );
    }

    // Both mid-road.
    final aPos = _midRoadPositionOf(a);
    final bPos = _midRoadPositionOf(b);
    if (aPos == null || bPos == null) return null;
    return match.map.roadDistance(aPos, bPos);
  }

  /// Derive the mid-road [RoadPosition] from [co]'s current progress,
  /// using [midRoadDestination] for segment direction.
  /// Returns null if segment direction is unknown.
  static RoadPosition? _midRoadPositionOf(CompanyOnMap co) {
    if (co.midRoadDestination != null) {
      return RoadPosition(
        currentNodeId: co.currentNode.id,
        nextNodeId: co.midRoadDestination!.nextNodeId,
        progress: co.progress,
      );
    }
    return null;
  }

  /// For each initiator with a [ProximityMergeIntent], update its
  /// [CompanyOnMap.midRoadDestination] to point to the target's current
  /// road position (so it tracks a moving target each tick).
  List<CompanyOnMap> _updateProximityMergeDestinations(
    List<CompanyOnMap> companies,
    Match match,
  ) {
    return [
      for (final co in companies)
        () {
          final intent = co.proximityMergeIntent;
          if (intent == null) return co;

          // Find target.
          final target = companies
              .where((c) => c.id == intent.targetCompanyId)
              .firstOrNull;
          if (target == null) return co;

          final targetPos = _roadPositionOf(target, match);
          if (targetPos == null) return co;

          // Update mid-road destination to target's current position.
          try {
            return const MoveCompany().setMidRoadDestination(
              company: co,
              dest: targetPos,
              map: match.map,
            );
          } catch (_) {
            return co;
          }
        }(),
    ];
  }

  /// Resolve proximity merges:
  /// - Cancel if: target gone, either company in battle, or distance > threshold.
  /// - Execute merge if initiator is co-located with target (same position).
  List<CompanyOnMap> _resolveProximityMerges(
    List<CompanyOnMap> companies,
    Match match,
  ) {
    var result = List<CompanyOnMap>.from(companies);

    // Collect initiators.
    final initiators = result
        .where((c) => c.proximityMergeIntent != null)
        .toList();

    for (final initiator in initiators) {
      final intent = initiator.proximityMergeIntent!;

      // Find initiator's index in result (may have changed due to prior iterations).
      final initiatorIdx = result.indexWhere((c) => c.id == initiator.id);
      if (initiatorIdx < 0) continue;

      final current = result[initiatorIdx];

      // Find target.
      final targetIdx =
          result.indexWhere((c) => c.id == intent.targetCompanyId);

      // --- Cancellation conditions ---

      // (1) Target no longer exists.
      if (targetIdx < 0) {
        result[initiatorIdx] = current.copyWith(
          proximityMergeIntent: null,
          midRoadDestination: null,
        );
        continue;
      }

      final target = result[targetIdx];

      // (2) Either company is in battle.
      if (current.battleId != null || target.battleId != null) {
        result[initiatorIdx] = current.copyWith(
          proximityMergeIntent: null,
          midRoadDestination: null,
        );
        continue;
      }

      // (3) Distance exceeds threshold.
      // Use actual current positions (not midRoadDestination) to check distance.
      final dist = _roadDistanceBetweenCompanies(current, target, match);
      if (dist != null && dist > kProximityMergeThreshold) {
        result[initiatorIdx] = current.copyWith(
          proximityMergeIntent: null,
          midRoadDestination: null,
        );
        continue;
      }

      // --- Merge condition: co-located (same node, same progress) ---
      final sameNode = current.currentNode.id == target.currentNode.id;
      final sameProgress =
          (current.progress - target.progress).abs() < 0.001;

      if (sameNode && sameProgress) {
        // Execute merge.
        try {
          final mergeResult = const MergeCompanies().merge(
            companyA: current,
            companyB: target,
            newId: current.id, // keep initiator's id
            overflowId: '${current.id}_overflow',
          );
          result
            ..removeAt(initiatorIdx)
            ..removeWhere((c) => c.id == target.id)
            ..add(mergeResult.primary.copyWith(proximityMergeIntent: null));
          if (mergeResult.overflow != null) {
            result.add(mergeResult.overflow!);
          }
        } catch (e) {
          // If merge fails, just cancel the intent.
          result[initiatorIdx] = current.copyWith(
            proximityMergeIntent: null,
            midRoadDestination: null,
          );
        }
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Victory check — delegates to VictoryChecker domain rule
  // ---------------------------------------------------------------------------

  MatchOutcome? _checkVictory(List<Castle> castles) =>
      const VictoryChecker().check(castles);
}
