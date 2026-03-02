import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/deploy_company.dart';
import 'package:iron_and_stone/domain/use_cases/move_company.dart';
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
    final current = state.valueOrNull ?? const CompanyListState();
    final idx = current.companies.indexWhere((c) => c.id == companyId);
    if (idx < 0) return;

    final company = current.companies[idx];
    final updated = const MoveCompany().setDestination(
      company: company,
      destination: destination,
      map: map,
    );

    final newList = List<CompanyOnMap>.from(current.companies)..[idx] = updated;
    state = AsyncData(current.copyWith(companies: newList, selectedCompanyId: null));

    ref.read(matchNotifierProvider.notifier).updateCompanies(newList);
  }

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
