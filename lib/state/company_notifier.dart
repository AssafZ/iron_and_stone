import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/deploy_company.dart';
import 'package:iron_and_stone/domain/use_cases/merge_companies.dart';
import 'package:iron_and_stone/domain/use_cases/move_company.dart';
import 'package:iron_and_stone/domain/use_cases/split_company.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

/// State for the company list + current selection.
final class CompanyListState {
  final List<CompanyOnMap> companies;

  /// The ID of the currently selected Company for two-step tap-to-move UX.
  final String? selectedCompanyId;

  const CompanyListState({
    this.companies = const [],
    this.selectedCompanyId,
  });

  CompanyListState copyWith({
    List<CompanyOnMap>? companies,
    Object? selectedCompanyId = _sentinel,
  }) {
    return CompanyListState(
      companies: companies ?? this.companies,
      selectedCompanyId: identical(selectedCompanyId, _sentinel)
          ? this.selectedCompanyId
          : selectedCompanyId as String?,
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
    state = AsyncData(current.copyWith(companies: updated));

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
    final updated = const MoveCompany().setDestination(
      company: company,
      destination: destination,
      map: map,
    );

    final newList = List<CompanyOnMap>.from(sourceList)..[idx] = updated;
    state = AsyncData(current.copyWith(companies: newList, selectedCompanyId: null));

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

    state = AsyncData(current.copyWith(companies: remaining, selectedCompanyId: null));
    ref.read(matchNotifierProvider.notifier).updateCompanies(remaining);
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

    state = AsyncData(current.copyWith(companies: updated, selectedCompanyId: null));
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

    state = AsyncData(current.copyWith(companies: advanced));
    ref.read(matchNotifierProvider.notifier).updateCompanies(advanced);
  }
}

/// The global [CompanyNotifier] provider.
final companyNotifierProvider =
    AsyncNotifierProvider<CompanyNotifier, CompanyListState>(CompanyNotifier.new);
