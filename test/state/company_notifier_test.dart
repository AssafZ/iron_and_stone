// T053: CompanyNotifier.setDestination must be a no-op when the company is
// currently locked in battle (company.battleId != null).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

MatchState _emptyState() {
  final map = GameMapFixture.build();
  return MatchState(
    match: Match(
      map: map,
      humanPlayer: Ownership.player,
      phase: MatchPhase.playing,
    ),
    castles: const [],
    companies: const [],
    activeBattles: const [],
  );
}

// ---------------------------------------------------------------------------
// T053 Tests
// ---------------------------------------------------------------------------

void main() {
  group('T053: CompanyNotifier.setDestination battleId guard', () {
    test(
      'setDestination is a no-op when company.battleId is set',
      () async {
        final map = GameMapFixture.build();
        final j1 = map.nodes.firstWhere((n) => n.id == 'j1');
        final j4 = map.nodes.firstWhere((n) => n.id == 'j4');

        // A company locked in battle at j1.
        final co = CompanyOnMap(
          id: 'player_co0',
          ownership: Ownership.player,
          currentNode: j1,
          company: Company(composition: {UnitRole.warrior: 5}),
          battleId: 'battle_j1', // IN BATTLE — move must be blocked
        );

        // Seed the match notifier with this company.
        final initialState = _emptyState().copyWith(companies: [co]);
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        // Wait for async build.
        await container.read(matchNotifierProvider.future);

        // Attempt to set a destination while locked in battle.
        await container.read(companyNotifierProvider.notifier).setDestination(
              companyId: 'player_co0',
              destination: j4,
              map: map,
            );

        // The company state must be unchanged — destination must still be null.
        // companyNotifierProvider initialises from matchNotifierProvider, so
        // its local companies list starts empty; the guard fires before any
        // local state is written, so the local companies list is still empty
        // (no company was updated).
        //
        // Alternative: verify via matchNotifierProvider that companies were
        // NOT synced back with a non-null destination.
        final matchCompanies =
            container.read(matchNotifierProvider).valueOrNull?.companies ?? [];
        final updated =
            matchCompanies.firstWhere((c) => c.id == 'player_co0');

        expect(
          updated.destination,
          isNull,
          reason:
              'setDestination must be a no-op when company.battleId != null',
        );
      },
    );

    test(
      'setDestination proceeds normally when company.battleId is null',
      () async {
        final map = GameMapFixture.build();
        final j1 = map.nodes.firstWhere((n) => n.id == 'j1');
        final j4 = map.nodes.firstWhere((n) => n.id == 'j4');

        // A free company (not in battle).
        final co = CompanyOnMap(
          id: 'player_co0',
          ownership: Ownership.player,
          currentNode: j1,
          company: Company(composition: {UnitRole.warrior: 5}),
          // battleId: null (default)
        );

        final initialState = _emptyState().copyWith(companies: [co]);
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        await container.read(companyNotifierProvider.notifier).setDestination(
              companyId: 'player_co0',
              destination: j4,
              map: map,
            );

        final matchCompanies =
            container.read(matchNotifierProvider).valueOrNull?.companies ?? [];
        final updated =
            matchCompanies.firstWhere((c) => c.id == 'player_co0');

        expect(
          updated.destination?.id,
          equals('j4'),
          reason: 'setDestination must set the destination when not in battle',
        );
      },
    );
  });
}
