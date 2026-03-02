import 'package:iron_and_stone/domain/entities/castle.dart';
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

  const MatchState({
    required this.match,
    required this.castles,
    required this.companies,
    this.matchOutcome,
  });

  MatchState copyWith({
    Match? match,
    List<Castle>? castles,
    List<CompanyOnMap>? companies,
    MatchOutcome? matchOutcome,
  }) {
    return MatchState(
      match: match ?? this.match,
      castles: castles ?? this.castles,
      companies: companies ?? this.companies,
      matchOutcome: matchOutcome ?? this.matchOutcome,
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
class MatchNotifier extends AsyncNotifier<MatchState> {
  static const _tickSeconds = 10.0;

  @override
  Future<MatchState> build() async {
    return _buildInitialState();
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Initialise a new single-player match.
  Future<void> newGame() async {
    state = const AsyncLoading();
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
    );

    final newPhase =
        result.battleTriggers.isNotEmpty ? MatchPhase.inBattle : MatchPhase.playing;

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
      ),
    );

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

    final castles = map.nodes.whereType<CastleNode>().map((node) {
      return Castle(
        id: node.id,
        ownership: node.ownership,
        garrison: _defaultGarrison(),
      );
    }).toList();

    final match = Match(
      map: map,
      humanPlayer: Ownership.player,
      phase: MatchPhase.playing,
    );

    return MatchState(match: match, castles: castles, companies: []);
  }

  static Map<UnitRole, int> _defaultGarrison() => {
        UnitRole.peasant: 5,
        UnitRole.warrior: 20,
        UnitRole.knight: 5,
        UnitRole.archer: 10,
        UnitRole.catapult: 2,
      };
}

/// The global [MatchNotifier] provider.
final matchNotifierProvider =
    AsyncNotifierProvider<MatchNotifier, MatchState>(MatchNotifier.new);
