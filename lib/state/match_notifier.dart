import 'package:iron_and_stone/data/drift/match_dao.dart';
import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/tick_match.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The combined state for the ongoing match.
final class MatchState {
  final Match match;
  final List<Castle> castles;
  final List<CompanyOnMap> companies;
  final MatchOutcome? matchOutcome;

  /// The currently active battles (empty when no battles are in progress).
  final List<ActiveBattle> activeBattles;

  const MatchState({
    required this.match,
    required this.castles,
    required this.companies,
    this.matchOutcome,
    this.activeBattles = const [],
  });

  MatchState copyWith({
    Match? match,
    List<Castle>? castles,
    List<CompanyOnMap>? companies,
    MatchOutcome? matchOutcome,
    List<ActiveBattle>? activeBattles,
  }) {
    return MatchState(
      match: match ?? this.match,
      castles: castles ?? this.castles,
      companies: companies ?? this.companies,
      matchOutcome: matchOutcome ?? this.matchOutcome,
      activeBattles: activeBattles ?? this.activeBattles,
    );
  }
}

/// Riverpod notifier that owns the full match lifecycle.
///
/// - [newGame]: initialises a fresh match from [GameMapFixture].
/// - [tick]: advances the game-loop by one step (called on a 10 s timer).
/// - [applyTickResult]: applies a [TickResult] to the current state.
/// - [addCompany] / [removeCompany]: called by [CompanyNotifier] to sync list.
///
/// Contains NO game-rule logic — all computation is delegated to [TickMatch].
///
/// Persistence: after each [tick] the full [MatchState] is saved via [MatchDao].
/// On cold start ([build]), the notifier attempts to restore a saved match
/// before falling back to a fresh [_buildInitialState].
class MatchNotifier extends AsyncNotifier<MatchState> {
  static const _tickSeconds = 10.0;

  /// The stable match ID used for all persistence operations.
  static const _persistedMatchId = 'current_match';

  MatchDao? _dao;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<MatchState> build() async {
    // Read DAO from provider — null in widget tests (no override), real in prod.
    _dao = ref.read(matchDaoProvider);
    if (_dao != null) {
      try {
        final saved = await _dao!.loadMatch(_persistedMatchId);
        if (saved != null) return saved;
      } catch (_) {
        // If persistence fails (e.g. schema change), fall through to fresh state.
        _dao = null;
      }
    }
    return _buildInitialState();
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Initialise a new single-player match.
  ///
  /// Deletes any previously persisted match before starting fresh.
  Future<void> newGame() async {
    state = const AsyncLoading();
    try {
      await _dao?.deleteMatch(_persistedMatchId);
    } catch (_) {
      // Ignore persistence errors on new game.
    }
    state = await AsyncValue.guard(() async => _buildInitialState());
  }

  /// Apply one game-loop tick.
  ///
  /// Delegates entirely to [TickMatch]; stores results back into state.
  /// Also syncs [CompanyNotifier] so AI-deployed companies appear on MapScreen.
  Future<TickResult?> tick() async {
    final current = state.valueOrNull;
    if (current == null) return null;

    // TickMatch now includes AiController decision + application internally,
    // so result.companies may include newly AI-deployed companies.
    final result = const TickMatch().tick(
      match: current.match,
      castles: current.castles,
      companies: current.companies,
      activeBattles: current.activeBattles,
    );

    final newActiveBattles = result.activeBattles;
    final newPhase = newActiveBattles.isNotEmpty
        ? MatchPhase.inBattle
        : MatchPhase.playing;

    state = AsyncData(
      current.copyWith(
        match: current.match.copyWith(
          elapsedTime: current.match.elapsedTime +
              Duration(seconds: _tickSeconds.toInt()),
          phase: result.matchOutcome != null ? MatchPhase.ended : newPhase,
        ),
        castles: result.castles,
        companies: result.companies,
        matchOutcome: result.matchOutcome,
        activeBattles: newActiveBattles,
      ),
    );

    // Persist snapshot after every tick.
    final updated = state.valueOrNull;
    if (updated != null) {
      try {
        await _dao?.saveMatch(matchId: _persistedMatchId, state: updated);
      } catch (_) {
        // Persistence failures must not crash the game loop.
      }
    }

    return result;
  }

  /// Update the companies list (called by [CompanyNotifier]).
  void updateCompanies(List<CompanyOnMap> companies) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(companies: companies));
  }

  /// Update a specific castle in the current state.
  void updateCastle(Castle castle) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = [
      for (final c in current.castles)
        if (c.id == castle.id) castle else c,
    ];
    state = AsyncData(current.copyWith(castles: updated));
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static MatchState _buildInitialState() {
    final map = GameMapFixture.build();

    // Castles start with no garrison — all soldiers are in companies.
    final castles = map.nodes.whereType<CastleNode>().map((node) {
      return Castle(
        id: node.id,
        ownership: node.ownership,
        garrison: const {},
      );
    }).toList();

    final match = Match(
      map: map,
      humanPlayer: Ownership.player,
      phase: MatchPhase.playing,
    );

    // Each side starts with one company stationed at their castle.
    final playerCastleNode = map.nodes
        .whereType<CastleNode>()
        .firstWhere((n) => n.ownership == Ownership.player);
    final aiCastleNode = map.nodes
        .whereType<CastleNode>()
        .firstWhere((n) => n.ownership == Ownership.ai);

    final startingComposition = {
      UnitRole.warrior: 3,
      UnitRole.archer: 3,
      UnitRole.peasant: 2,
      UnitRole.knight: 1,
      UnitRole.catapult: 1,
    };

    final playerCompany = CompanyOnMap(
      id: 'player_co0',
      ownership: Ownership.player,
      currentNode: playerCastleNode,
      company: Company(composition: Map.from(startingComposition)),
    );

    final aiCompany = CompanyOnMap(
      id: 'ai_co0',
      ownership: Ownership.ai,
      currentNode: aiCastleNode,
      company: Company(composition: Map.from(startingComposition)),
    );

    return MatchState(
      match: match,
      castles: castles,
      companies: [playerCompany, aiCompany],
    );
  }
}

/// Provides the [MatchDao] used for game-state persistence.
///
/// Defaults to `null` (no persistence). Widget tests use the default so no
/// real SQLite database is opened. Production code overrides this in
/// [ProviderScope] with a real [MatchDao] instance.
final matchDaoProvider = Provider<MatchDao?>((ref) => null);

/// The global [MatchNotifier] provider.
final matchNotifierProvider =
    AsyncNotifierProvider<MatchNotifier, MatchState>(MatchNotifier.new);
