// T023c: MatchNotifier.advanceBattleRound(String battleId) — failing tests.
//
// These tests verify that advanceBattleRound:
//   1. Advances exactly one round on the matching ActiveBattle.
//   2. Applies full Phase C post-battle cleanup when the round resolves the battle
//      (survivor composition updated, zero-soldier companies removed, battleId cleared,
//       ActiveBattle removed from state.activeBattles).
//   3. Is a no-op when no ActiveBattle with the given battleId exists.
//   4. Persists state (smoke-test: state is updated in MatchNotifier).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _playerCastle = CastleNode(
  id: 'player_castle',
  x: 0.0,
  y: 0.0,
  ownership: Ownership.player,
);

const _aiCastle = CastleNode(
  id: 'ai_castle',
  x: 300.0,
  y: 0.0,
  ownership: Ownership.ai,
);

const _junction = RoadJunctionNode(id: 'junction_mid', x: 150.0, y: 0.0);

GameMap _makeMap() => GameMap(
      nodes: [_playerCastle, _junction, _aiCastle],
      edges: [
        RoadEdge(from: _playerCastle, to: _junction, length: 150.0),
        RoadEdge(from: _junction, to: _playerCastle, length: 150.0),
        RoadEdge(from: _junction, to: _aiCastle, length: 150.0),
        RoadEdge(from: _aiCastle, to: _junction, length: 150.0),
      ],
    );

Match _makeMatch() => Match(
      map: _makeMap(),
      humanPlayer: Ownership.player,
      phase: MatchPhase.playing,
    );

MatchState _stateWithOngoingBattle({
  required ActiveBattle activeBattle,
  required List<CompanyOnMap> companies,
}) {
  final map = _makeMap();
  final castles = map.nodes.whereType<CastleNode>().map((n) {
    return Castle(id: n.id, ownership: n.ownership, garrison: const {});
  }).toList();

  return MatchState(
    match: _makeMatch(),
    castles: castles,
    companies: companies,
    activeBattles: [activeBattle],
  );
}

/// A fake MatchNotifier that initialises with a given [MatchState].
final class _FakeMatchNotifier extends MatchNotifier {
  final MatchState _initialState;
  _FakeMatchNotifier(this._initialState);

  @override
  Future<MatchState> build() async => _initialState;
}

ProviderContainer _makeContainer(MatchState initialState) {
  return ProviderContainer(
    overrides: [
      matchNotifierProvider
          .overrideWith(() => _FakeMatchNotifier(initialState)),
    ],
  );
}

// ---------------------------------------------------------------------------
// T023c Tests
// ---------------------------------------------------------------------------

void main() {
  group('T023c: MatchNotifier.advanceBattleRound', () {
    test(
      'T023c-1: advances roundNumber by 1 on the matching ActiveBattle',
      () async {
        // Long-lived battle so it won't resolve in one round.
        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 20})],
          defenders: [Company(composition: {UnitRole.warrior: 20})],
        );
        final activeBattle = ActiveBattle(
          nodeId: 'junction_mid',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );
        final playerCo = CompanyOnMap(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          company: Company(composition: {UnitRole.warrior: 20}),
          battleId: activeBattle.id,
        );
        final aiCo = CompanyOnMap(
          id: 'ai1',
          ownership: Ownership.ai,
          currentNode: _junction,
          company: Company(composition: {UnitRole.warrior: 20}),
          battleId: activeBattle.id,
        );
        final initialState = _stateWithOngoingBattle(
          activeBattle: activeBattle,
          companies: [playerCo, aiCo],
        );
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        await container
            .read(matchNotifierProvider.notifier)
            .advanceBattleRound(activeBattle.id);

        final newState = container.read(matchNotifierProvider).valueOrNull!;
        final updatedBattle = newState.activeBattles
            .firstWhere((ab) => ab.id == activeBattle.id);

        expect(
          updatedBattle.battle.roundNumber,
          equals(battle.roundNumber + 1),
          reason: 'advanceBattleRound must resolve exactly one round',
        );
      },
    );

    test(
      'T023c-2: no-op when no ActiveBattle matches the given battleId',
      () async {
        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 10})],
          defenders: [Company(composition: {UnitRole.warrior: 10})],
        );
        final activeBattle = ActiveBattle(
          nodeId: 'junction_mid',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );
        final playerCo = CompanyOnMap(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          company: Company(composition: {UnitRole.warrior: 10}),
          battleId: activeBattle.id,
        );
        final aiCo = CompanyOnMap(
          id: 'ai1',
          ownership: Ownership.ai,
          currentNode: _junction,
          company: Company(composition: {UnitRole.warrior: 10}),
          battleId: activeBattle.id,
        );
        final initialState = _stateWithOngoingBattle(
          activeBattle: activeBattle,
          companies: [playerCo, aiCo],
        );
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        // Call with a non-existent battleId — must not throw or mutate state.
        await container
            .read(matchNotifierProvider.notifier)
            .advanceBattleRound('battle_nonexistent');

        final newState = container.read(matchNotifierProvider).valueOrNull!;
        // The existing active battle must be unchanged.
        expect(newState.activeBattles, hasLength(1));
        expect(
          newState.activeBattles.first.battle.roundNumber,
          equals(battle.roundNumber),
          reason: 'advanceBattleRound with unknown id must be a no-op',
        );
      },
    );

    test(
      'T023c-3: when round resolves the battle (attackersWin), ActiveBattle is '
      'removed and survivor composition is updated',
      () async {
        // 10 knights vs 1 peasant — attackers win in 1 round.
        final battle = Battle(
          attackers: [Company(composition: {UnitRole.knight: 10})],
          defenders: [Company(composition: {UnitRole.peasant: 1})],
        );
        final activeBattle = ActiveBattle(
          nodeId: 'junction_mid',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );
        final playerCo = CompanyOnMap(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          company: Company(composition: {UnitRole.knight: 10}),
          battleId: activeBattle.id,
        );
        final aiCo = CompanyOnMap(
          id: 'ai1',
          ownership: Ownership.ai,
          currentNode: _junction,
          company: Company(composition: {UnitRole.peasant: 1}),
          battleId: activeBattle.id,
        );
        final initialState = _stateWithOngoingBattle(
          activeBattle: activeBattle,
          companies: [playerCo, aiCo],
        );
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        // Advance until resolved (max 20 rounds to avoid infinite loop).
        for (var i = 0; i < 20; i++) {
          final s = container.read(matchNotifierProvider).valueOrNull!;
          final ab = s.activeBattles.where((ab) => ab.id == activeBattle.id);
          if (ab.isEmpty) break;
          await container
              .read(matchNotifierProvider.notifier)
              .advanceBattleRound(activeBattle.id);
        }

        final finalState = container.read(matchNotifierProvider).valueOrNull!;

        // Battle must be resolved and removed from activeBattles.
        expect(
          finalState.activeBattles.any((ab) => ab.id == activeBattle.id),
          isFalse,
          reason: 'Resolved ActiveBattle must be removed from state.activeBattles',
        );

        // Attacker (p1) must survive with battleId cleared.
        final survivor = finalState.companies.where((c) => c.id == 'p1');
        expect(
          survivor,
          isNotEmpty,
          reason: 'Attacker (p1) must survive an attackersWin battle',
        );
        expect(
          survivor.first.battleId,
          isNull,
          reason: 'Survivor battleId must be null after cleanup',
        );

        // Defender (ai1, 1 peasant) must be removed (0 soldiers).
        expect(
          finalState.companies.any((c) => c.id == 'ai1'),
          isFalse,
          reason: 'Defeated defender must be removed from state.companies',
        );
      },
    );

    test(
      'T023c-4: when round resolves with draw, both companies are removed',
      () async {
        // 1 knight vs 1 knight — should draw.
        final battle = Battle(
          attackers: [Company(composition: {UnitRole.knight: 1})],
          defenders: [Company(composition: {UnitRole.knight: 1})],
        );
        final activeBattle = ActiveBattle(
          nodeId: 'junction_mid',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );
        final playerCo = CompanyOnMap(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          company: Company(composition: {UnitRole.knight: 1}),
          battleId: activeBattle.id,
        );
        final aiCo = CompanyOnMap(
          id: 'ai1',
          ownership: Ownership.ai,
          currentNode: _junction,
          company: Company(composition: {UnitRole.knight: 1}),
          battleId: activeBattle.id,
        );
        final initialState = _stateWithOngoingBattle(
          activeBattle: activeBattle,
          companies: [playerCo, aiCo],
        );
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        // Advance until resolved.
        for (var i = 0; i < 20; i++) {
          final s = container.read(matchNotifierProvider).valueOrNull!;
          final ab = s.activeBattles.where((ab) => ab.id == activeBattle.id);
          if (ab.isEmpty) break;
          await container
              .read(matchNotifierProvider.notifier)
              .advanceBattleRound(activeBattle.id);
        }

        final finalState = container.read(matchNotifierProvider).valueOrNull!;

        // Both companies must be gone (draw → both eliminated).
        expect(
          finalState.companies.any((c) => c.id == 'p1' || c.id == 'ai1'),
          isFalse,
          reason: 'Both companies must be removed after a draw',
        );

        // ActiveBattle must be gone.
        expect(
          finalState.activeBattles.any((ab) => ab.id == activeBattle.id),
          isFalse,
        );
      },
    );

    test(
      'T023c-5: calling advanceBattleRound twice increments roundNumber to 2',
      () async {
        // Long-lived battle so it won't resolve in two rounds.
        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 20})],
          defenders: [Company(composition: {UnitRole.warrior: 20})],
        );
        final activeBattle = ActiveBattle(
          nodeId: 'junction_mid',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );
        final playerCo = CompanyOnMap(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          company: Company(composition: {UnitRole.warrior: 20}),
          battleId: activeBattle.id,
        );
        final aiCo = CompanyOnMap(
          id: 'ai1',
          ownership: Ownership.ai,
          currentNode: _junction,
          company: Company(composition: {UnitRole.warrior: 20}),
          battleId: activeBattle.id,
        );
        final initialState = _stateWithOngoingBattle(
          activeBattle: activeBattle,
          companies: [playerCo, aiCo],
        );
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        // First advance: round 0 → 1
        await container
            .read(matchNotifierProvider.notifier)
            .advanceBattleRound(activeBattle.id);

        final stateAfter1 = container.read(matchNotifierProvider).valueOrNull!;
        final battleAfter1 = stateAfter1.activeBattles
            .firstWhere((ab) => ab.id == activeBattle.id);
        expect(battleAfter1.battle.roundNumber, equals(1),
            reason: 'First advanceBattleRound must increment to round 1');

        // Second advance: round 1 → 2
        await container
            .read(matchNotifierProvider.notifier)
            .advanceBattleRound(activeBattle.id);

        final stateAfter2 = container.read(matchNotifierProvider).valueOrNull!;
        final battleAfter2 = stateAfter2.activeBattles
            .firstWhere((ab) => ab.id == activeBattle.id);
        expect(battleAfter2.battle.roundNumber, equals(2),
            reason: 'Second advanceBattleRound must increment to round 2');
      },
    );

    test(
      'T023c-6: tick() is a no-op when match.phase == inBattle',
      () async {
        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 10})],
          defenders: [Company(composition: {UnitRole.warrior: 10})],
        );
        final activeBattle = ActiveBattle(
          nodeId: 'junction_mid',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );
        final playerCo = CompanyOnMap(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          company: Company(composition: {UnitRole.warrior: 10}),
          battleId: activeBattle.id,
        );
        final aiCo = CompanyOnMap(
          id: 'ai1',
          ownership: Ownership.ai,
          currentNode: _junction,
          company: Company(composition: {UnitRole.warrior: 10}),
          battleId: activeBattle.id,
        );
        // State with inBattle phase.
        final map = _makeMap();
        final castles = map.nodes.whereType<CastleNode>().map((n) {
          return Castle(id: n.id, ownership: n.ownership, garrison: const {});
        }).toList();
        final initialState = MatchState(
          match: Match(
            map: map,
            humanPlayer: Ownership.player,
            phase: MatchPhase.inBattle,
          ),
          castles: castles,
          companies: [playerCo, aiCo],
          activeBattles: [activeBattle],
        );
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        // Call tick — must be a no-op (returns null, state unchanged).
        final result =
            await container.read(matchNotifierProvider.notifier).tick();

        expect(result, isNull,
            reason: 'tick() must return null when phase is inBattle');
        final newState = container.read(matchNotifierProvider).valueOrNull!;
        // activeBattles must be unchanged (battle still at round 0).
        expect(
          newState.activeBattles.first.battle.roundNumber,
          equals(0),
          reason: 'tick() must not change battle state when phase is inBattle',
        );
      },
    );

    test(
      'T023c-7: after battle resolves via advanceBattleRound, match.phase '
      'returns to playing',
      () async {
        // One-round battle: 10 knights vs 1 peasant.
        final battle = Battle(
          attackers: [Company(composition: {UnitRole.knight: 10})],
          defenders: [Company(composition: {UnitRole.peasant: 1})],
        );
        final activeBattle = ActiveBattle(
          nodeId: 'junction_mid',
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );
        final playerCo = CompanyOnMap(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
          company: Company(composition: {UnitRole.knight: 10}),
          battleId: activeBattle.id,
        );
        final aiCo = CompanyOnMap(
          id: 'ai1',
          ownership: Ownership.ai,
          currentNode: _junction,
          company: Company(composition: {UnitRole.peasant: 1}),
          battleId: activeBattle.id,
        );
        final map = _makeMap();
        final castles = map.nodes.whereType<CastleNode>().map((n) {
          return Castle(id: n.id, ownership: n.ownership, garrison: const {});
        }).toList();
        // Start with inBattle phase.
        final initialState = MatchState(
          match: Match(
            map: map,
            humanPlayer: Ownership.player,
            phase: MatchPhase.inBattle,
          ),
          castles: castles,
          companies: [playerCo, aiCo],
          activeBattles: [activeBattle],
        );
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        // Advance until battle resolves.
        for (var i = 0; i < 20; i++) {
          final s = container.read(matchNotifierProvider).valueOrNull!;
          if (s.activeBattles.isEmpty) break;
          await container
              .read(matchNotifierProvider.notifier)
              .advanceBattleRound(activeBattle.id);
        }

        final finalState = container.read(matchNotifierProvider).valueOrNull!;

        expect(finalState.activeBattles, isEmpty,
            reason: 'Battle must be resolved');
        expect(finalState.match.phase, equals(MatchPhase.playing),
            reason: 'Phase must return to playing after all battles resolve');
      },
    );
  });
}
