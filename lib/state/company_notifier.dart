import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/proximity_merge_intent.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/movement_rules.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/deploy_company.dart';
import 'package:iron_and_stone/domain/use_cases/merge_companies.dart';
import 'package:iron_and_stone/domain/use_cases/move_company.dart';
import 'package:iron_and_stone/domain/use_cases/split_company.dart';
import 'package:iron_and_stone/domain/value_objects/node_occupancy.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

/// State for the company list + current selection.
final class CompanyListState {
  final List<CompanyOnMap> companies;

  /// The ID of the currently selected Company for two-step tap-to-move UX.
  final String? selectedCompanyId;

  /// Per-node occupancy map: keyed by node ID, holds the ordered slot
  /// assignment for stationary companies at that node.
  ///
  /// Transient UI state — not persisted between sessions.
  /// Default is an empty map.
  final Map<String, NodeOccupancy> nodeOccupancy;

  const CompanyListState({
    this.companies = const [],
    this.selectedCompanyId,
    this.nodeOccupancy = const {},
  });

  CompanyListState copyWith({
    List<CompanyOnMap>? companies,
    Object? selectedCompanyId = _sentinel,
    Map<String, NodeOccupancy>? nodeOccupancy,
  }) {
    return CompanyListState(
      companies: companies ?? this.companies,
      selectedCompanyId: identical(selectedCompanyId, _sentinel)
          ? this.selectedCompanyId
          : selectedCompanyId as String?,
      nodeOccupancy: nodeOccupancy ?? this.nodeOccupancy,
    );
  }

  static const Object _sentinel = Object();
}

/// Notifier that owns the list of [CompanyOnMap] entities and selection state.
///
/// - [deployCompany]: remove units from a castle garrison and place a Company.
/// - [setDestination]: assign a movement destination to a Company.
/// - [selectCompany]: mark a Company as selected.
/// - [clearSelection]: deselect.
/// - [advanceTick]: advance all Company positions by one tick.
///
/// Contains NO game-rule logic — delegates to [DeployCompany] and [MoveCompany].
class CompanyNotifier extends AsyncNotifier<CompanyListState> {
  int _idCounter = 0;

  @override
  Future<CompanyListState> build() async {
    return const CompanyListState();
  }

  // ---------------------------------------------------------------------------
  // Two-step selection UX (FR-011)
  // ---------------------------------------------------------------------------

  /// Select a Company by ID.
  void selectCompany(String id) {
    final current = state.valueOrNull ?? const CompanyListState();
    state = AsyncData(current.copyWith(selectedCompanyId: id));
  }

  /// Clear the current selection.
  void clearSelection() {
    final current = state.valueOrNull ?? const CompanyListState();
    state = AsyncData(current.copyWith(selectedCompanyId: null));
  }

  // ---------------------------------------------------------------------------
  // Deployment
  // ---------------------------------------------------------------------------

  /// Deploy a Company from the given castle garrison.
  ///
  /// Delegates to [DeployCompany] use case.
  Future<void> deployCompany({
    required String castleId,
    required CastleNode castleNode,
    required Map<UnitRole, int> composition,
    required GameMap map,
  }) async {
    final matchState = ref.read(matchNotifierProvider).valueOrNull;
    if (matchState == null) return;

    final castle = matchState.castles.firstWhere((c) => c.id == castleId);
    final id = 'co${_idCounter++}';

    final result = const DeployCompany().deploy(
      castle: castle,
      composition: composition,
      castleNode: castleNode,
      map: map,
      companyId: id,
    );

    // Update the castle garrison in the match notifier.
    ref.read(matchNotifierProvider.notifier).updateCastle(result.updatedCastle);

    // Add Company to the list.
    final current = state.valueOrNull ?? const CompanyListState();
    final updated = [...current.companies, result.company];

    // Record the new company's arrival slot in NodeOccupancy.
    final nodeId = castleNode.id;
    final existingOcc = current.nodeOccupancy[nodeId] ??
        NodeOccupancy(nodeId: nodeId, orderedIds: []);
    final updatedOcc = Map<String, NodeOccupancy>.from(current.nodeOccupancy)
      ..[nodeId] = existingOcc.withArrival(result.company.id);

    state = AsyncData(current.copyWith(companies: updated, nodeOccupancy: updatedOcc));

    // Sync companies back to match notifier.
    ref.read(matchNotifierProvider.notifier).updateCompanies(updated);
  }

  // ---------------------------------------------------------------------------
  // Movement
  // ---------------------------------------------------------------------------

  /// Assign a destination to a Company (validates road path).
  ///
  /// Delegates to [MoveCompany.setDestination].
  Future<void> setDestination({
    required String companyId,
    required MapNode destination,
    required GameMap map,
  }) async {
    // Use the authoritative match-state company list so tick-advanced
    // positions are always up to date.
    final matchState = ref.read(matchNotifierProvider).valueOrNull;
    final authoritativeList = matchState?.companies ?? [];
    final current = state.valueOrNull ?? const CompanyListState();

    // Find in authoritative list first, fallback to local.
    final sourceList = authoritativeList.isNotEmpty ? authoritativeList : current.companies;
    final idx = sourceList.indexWhere((c) => c.id == companyId);
    if (idx < 0) return;

    final company = sourceList[idx];
    // T053: blocked — cannot reroute a company that is locked in battle.
    if (company.battleId != null) return;
    final updated = const MoveCompany().setDestination(
      company: company,
      destination: destination,
      map: map,
    );

    final newList = List<CompanyOnMap>.from(sourceList)..[idx] = updated;

    // If the company was stationary, remove it from its node's occupancy slot
    // (it is now departing and should not occupy a static offset position).
    var updatedOcc = current.nodeOccupancy;
    if (_isStationary(company)) {
      final nodeId = company.currentNode.id;
      final existingOcc = updatedOcc[nodeId];
      if (existingOcc != null) {
        updatedOcc = Map<String, NodeOccupancy>.from(updatedOcc)
          ..[nodeId] = existingOcc.withDeparture(companyId);
      }
    }

    state = AsyncData(current.copyWith(
      companies: newList,
      nodeOccupancy: updatedOcc,
    ));

    ref.read(matchNotifierProvider.notifier).updateCompanies(newList);
  }

  /// Assign a mid-road fractional stop to a Company.
  ///
  /// The company will march to the exact fractional position described by
  /// [dest] and stop there. Delegates to [MoveCompany.setMidRoadDestination].
  Future<void> setMidRoadDestination({
    required String companyId,
    required RoadPosition dest,
    required GameMap map,
  }) async {
    final matchState = ref.read(matchNotifierProvider).valueOrNull;
    final authoritativeList = matchState?.companies ?? [];
    final current = state.valueOrNull ?? const CompanyListState();

    final sourceList = authoritativeList.isNotEmpty ? authoritativeList : current.companies;
    final idx = sourceList.indexWhere((c) => c.id == companyId);
    if (idx < 0) return;

    final company = sourceList[idx];
    if (company.battleId != null) return;

    final updated = const MoveCompany().setMidRoadDestination(
      company: company,
      dest: dest,
      map: map,
    );

    final newList = List<CompanyOnMap>.from(sourceList)..[idx] = updated;

    // If the company was stationary, remove it from its node's occupancy slot.
    var updatedOcc = current.nodeOccupancy;
    if (_isStationary(company)) {
      final nodeId = company.currentNode.id;
      final existingOcc = updatedOcc[nodeId];
      if (existingOcc != null) {
        updatedOcc = Map<String, NodeOccupancy>.from(updatedOcc)
          ..[nodeId] = existingOcc.withDeparture(companyId);
      }
    }

    state = AsyncData(current.copyWith(
      companies: newList,
      nodeOccupancy: updatedOcc,
    ));
    ref.read(matchNotifierProvider.notifier).updateCompanies(newList);
  }

  // ---------------------------------------------------------------------------
  // Merge
  // ---------------------------------------------------------------------------

  /// Merge two Companies into one (with optional overflow Company).
  ///
  /// Delegates to [MergeCompanies] use case.
  /// Removes both input Companies from the list and adds the result(s).
  Future<void> mergeCompanies(String idA, String idB) async {
    final matchState = ref.read(matchNotifierProvider).valueOrNull;
    final sourceList = matchState?.companies ??
        (state.valueOrNull ?? const CompanyListState()).companies;
    final current = state.valueOrNull ?? const CompanyListState();

    final a = sourceList.firstWhere((c) => c.id == idA);
    final b = sourceList.firstWhere((c) => c.id == idB);

    final newPrimaryId = 'co${_idCounter++}';
    final newOverflowId = 'co${_idCounter++}';

    final result = const MergeCompanies().merge(
      companyA: a,
      companyB: b,
      newId: newPrimaryId,
      overflowId: newOverflowId,
    );

    final remaining = sourceList
        .where((c) => c.id != idA && c.id != idB)
        .toList();
    remaining.add(result.primary);
    if (result.overflow != null) remaining.add(result.overflow!);

    // Update nodeOccupancy: remove both input companies, add the merged result(s).
    final nodeId = a.currentNode.id;
    var updatedOcc = current.nodeOccupancy;
    final existingOcc = updatedOcc[nodeId];
    if (existingOcc != null) {
      var newOcc = existingOcc.withDeparture(idA).withDeparture(idB);
      newOcc = newOcc.withArrival(result.primary.id);
      if (result.overflow != null) {
        newOcc = newOcc.withArrival(result.overflow!.id);
      }
      updatedOcc = Map<String, NodeOccupancy>.from(updatedOcc)..[nodeId] = newOcc;
    }

    state = AsyncData(current.copyWith(
      companies: remaining,
      nodeOccupancy: updatedOcc,
    ));
    ref.read(matchNotifierProvider.notifier).updateCompanies(remaining);
  }

  // ---------------------------------------------------------------------------
  // Proximity Merge
  // ---------------------------------------------------------------------------

  /// Initiate a proximity-based merge where [initiatorId] will auto-march
  /// toward [targetId] and merge on arrival.
  ///
  /// Validates that the road distance is within [kProximityMergeThreshold].
  /// Sets [ProximityMergeIntent] on the initiator and assigns a mid-road
  /// destination pointing to the target's current road position.
  ///
  /// Does nothing if either company is not found, is in battle, or the
  /// distance exceeds the threshold.
  Future<void> initiateProximityMerge({
    required String initiatorId,
    required String targetId,
  }) async {
    final matchState = ref.read(matchNotifierProvider).valueOrNull;
    final sourceList = matchState?.companies ??
        (state.valueOrNull ?? const CompanyListState()).companies;
    final current = state.valueOrNull ?? const CompanyListState();
    final map = matchState?.match.map;
    if (map == null) return;

    final initiatorIdx = sourceList.indexWhere((c) => c.id == initiatorId);
    final targetIdx = sourceList.indexWhere((c) => c.id == targetId);
    if (initiatorIdx < 0 || targetIdx < 0) return;

    final initiator = sourceList[initiatorIdx];
    final target = sourceList[targetIdx];

    // Bail if either is in battle.
    if (initiator.battleId != null || target.battleId != null) return;

    // Validate distance.
    final targetPos = _roadPositionOf(target, map);
    if (targetPos == null) return;

    final initiatorPos = _roadPositionOf(initiator, map);
    if (initiatorPos != null) {
      final dist = map.roadDistance(initiatorPos, targetPos);
      if (dist > kProximityMergeThreshold) return;
    }

    // Set intent and mid-road destination on initiator.
    final intent = ProximityMergeIntent(targetCompanyId: targetId);
    var updatedInitiator = initiator.copyWith(proximityMergeIntent: intent);

    // Assign mid-road destination = target's current position.
    try {
      updatedInitiator = const MoveCompany().setMidRoadDestination(
        company: updatedInitiator,
        dest: targetPos,
        map: map,
      );
    } catch (_) {
      // If setMidRoadDestination fails (e.g. invalid segment), clear intent.
      updatedInitiator = initiator.copyWith(proximityMergeIntent: null);
      return;
    }

    final newList = List<CompanyOnMap>.from(sourceList)
      ..[initiatorIdx] = updatedInitiator;

    // Remove from occupancy slot if previously stationary.
    var updatedOcc = current.nodeOccupancy;
    if (_isStationary(initiator)) {
      final nodeId = initiator.currentNode.id;
      final existingOcc = updatedOcc[nodeId];
      if (existingOcc != null) {
        updatedOcc = Map<String, NodeOccupancy>.from(updatedOcc)
          ..[nodeId] = existingOcc.withDeparture(initiatorId);
      }
    }

    state = AsyncData(current.copyWith(
      companies: newList,
      nodeOccupancy: updatedOcc,
    ));
    ref.read(matchNotifierProvider.notifier).updateCompanies(newList);
  }

  /// Derive a [RoadPosition] from a [CompanyOnMap].
  ///
  /// - If the company has a [CompanyOnMap.midRoadDestination], use it directly.
  /// - If the company is at a node (progress == 0), create a zero-progress
  ///   [RoadPosition] using any outgoing edge from the node.
  /// - Otherwise return null (mid-road without known next node).
  static RoadPosition? _roadPositionOf(CompanyOnMap co, GameMap map) {
    if (co.midRoadDestination != null) return co.midRoadDestination;
    if (co.progress == 0.0) {
      final edge =
          map.edges.where((e) => e.from.id == co.currentNode.id).firstOrNull;
      if (edge == null) return null;
      return RoadPosition(
        currentNodeId: co.currentNode.id,
        nextNodeId: edge.to.id,
        progress: 0.0,
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Split
  // ---------------------------------------------------------------------------

  /// Split a Company into two using a role-based [splitMap].
  ///
  /// Delegates to [SplitCompany] use case.
  /// Replaces the original Company in the list with the kept Company and adds
  /// the new split-off Company.
  Future<void> splitCompany(String id, Map<UnitRole, int> splitMap) async {
    final matchState = ref.read(matchNotifierProvider).valueOrNull;
    final sourceList = matchState?.companies ??
        (state.valueOrNull ?? const CompanyListState()).companies;
    final current = state.valueOrNull ?? const CompanyListState();

    final idx = sourceList.indexWhere((c) => c.id == id);
    if (idx < 0) return;

    final original = sourceList[idx];
    final newSplitId = 'co${_idCounter++}';

    final result = const SplitCompany().split(
      company: original,
      splitComposition: splitMap,
      keptId: id,
      splitId: newSplitId,
    );

    final updated = List<CompanyOnMap>.from(sourceList);
    updated[idx] = result.kept;
    updated.add(result.splitOff);

    // Update nodeOccupancy: remove the original company, add both new companies.
    final nodeId = original.currentNode.id;
    var updatedOcc = current.nodeOccupancy;
    final existingOcc = updatedOcc[nodeId];
    if (existingOcc != null) {
      var newOcc = existingOcc.withDeparture(id);
      newOcc = newOcc.withArrival(result.kept.id).withArrival(result.splitOff.id);
      updatedOcc = Map<String, NodeOccupancy>.from(updatedOcc)..[nodeId] = newOcc;
    }

    state = AsyncData(current.copyWith(
      companies: updated,
      nodeOccupancy: updatedOcc,
    ));
    ref.read(matchNotifierProvider.notifier).updateCompanies(updated);
  }

  // ---------------------------------------------------------------------------
  // Tick
  // ---------------------------------------------------------------------------

  /// Advance all Company positions by one tick.
  void advanceTick({required GameMap map, required double tickSeconds}) {
    final current = state.valueOrNull ?? const CompanyListState();
    final moveUseCase = const MoveCompany();

    final advanced = current.companies.map((co) {
      return moveUseCase.advance(company: co, map: map, tickSeconds: tickSeconds);
    }).toList();

    // _onTickReconcile: rebuild the full nodeOccupancy map after advancing
    // positions — companies may have arrived at a new node (becoming stationary)
    // or departed from their previous node (now in transit).  Using
    // _rebuildOccupancyMap gives a deterministic lexicographic ordering for any
    // newly stationary company while preserving nothing for in-transit ones.
    final reconciledOcc = _rebuildOccupancyMap(advanced);

    state = AsyncData(current.copyWith(companies: advanced, nodeOccupancy: reconciledOcc));
    ref.read(matchNotifierProvider.notifier).updateCompanies(advanced);
  }
}

/// The global [CompanyNotifier] provider.
final companyNotifierProvider =
    AsyncNotifierProvider<CompanyNotifier, CompanyListState>(CompanyNotifier.new);

// ---------------------------------------------------------------------------
// State-layer helpers (re-exposed from domain for convenience)
// ---------------------------------------------------------------------------

/// Returns `true` if [company] is stationary at its current node:
/// - destination is null, OR
/// - destination.id == currentNode.id
bool _isStationary(CompanyOnMap company) => isStationary(company);

/// Derives a [NodeOccupancy] for [nodeId] from [allCompanies] using the
/// cold-start deterministic approach (lexicographic sort by id).
NodeOccupancy _deriveOccupancy(
  String nodeId,
  List<CompanyOnMap> allCompanies,
) =>
    deriveOccupancy(nodeId, allCompanies);

/// Rebuilds the full [nodeOccupancy] map for all nodes represented in
/// [companies]. Only stationary companies are included.
Map<String, NodeOccupancy> _rebuildOccupancyMap(List<CompanyOnMap> companies) {
  final nodeIds = companies
      .where(_isStationary)
      .map((c) => c.currentNode.id)
      .toSet();
  return {
    for (final nodeId in nodeIds) nodeId: _deriveOccupancy(nodeId, companies),
  };
}
