// T053: CompanyNotifier.setDestination must be a no-op when the company is
// currently locked in battle (company.battleId != null).
// T030: splitCompany on a mid-road company inherits (currentNode, progress)
// and both halves receive distinct slot offsets from _buildSlotMap.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

// ---------------------------------------------------------------------------
// Slot-map mirror (mirrors _slotKey / _buildSlotMap from map_screen.dart)
// ---------------------------------------------------------------------------

const double _kSlotRadius = 28.0;
const _kSlotOffsets = [
  (0.0, 0.0),
  (_kSlotRadius, 0.0),
  (-_kSlotRadius, 0.0),
  (0.0, -_kSlotRadius),
  (0.0, _kSlotRadius),
  (-_kSlotRadius, -_kSlotRadius),
  (_kSlotRadius, -_kSlotRadius),
  (-_kSlotRadius, _kSlotRadius),
  (_kSlotRadius, _kSlotRadius),
];

String _slotKey(CompanyOnMap co) {
  if (co.battleId != null || co.progress <= 0.0 || co.destination != null) {
    return co.currentNode.id;
  }
  final nextId = co.midRoadDestination?.nextNodeId ?? co.currentNode.id;
  return '${co.currentNode.id}__${nextId}_${co.progress.toStringAsFixed(3)}';
}

Map<String, List<String>> _buildSlotMap(List<CompanyOnMap> companies) {
  final map = <String, List<String>>{};
  for (final co in companies) {
    final isStationary = co.battleId != null ||
        co.destination == null ||
        co.destination!.id == co.currentNode.id;
    if (!isStationary) continue;
    if (co.currentNode.runtimeType.toString().contains('Castle')) continue;
    map.putIfAbsent(_slotKey(co), () => []).add(co.id);
  }
  for (final ids in map.values) {
    ids.sort();
  }
  return map;
}

(double, double) _offsetForCompany(
  CompanyOnMap co,
  Map<String, List<String>> slotMap,
) {
  if (co.battleId == null &&
      co.destination != null &&
      co.destination!.id != co.currentNode.id) {
    return (0.0, 0.0);
  }
  final ids = slotMap[_slotKey(co)];
  if (ids == null) return (0.0, 0.0);
  final slot = ids.indexOf(co.id);
  if (slot < 0 || slot >= _kSlotOffsets.length) return (0.0, 0.0);
  return _kSlotOffsets[slot];
}

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

  // ---------------------------------------------------------------------------
  // T030 [US5]: splitCompany on a mid-road company
  // ---------------------------------------------------------------------------

  group('T030 [US5]: splitCompany at mid-road position', () {
    test(
      'both halves inherit (currentNode, progress) and midRoadDestination is null',
      () async {
        final map = GameMapFixture.build();
        final j1 = map.nodes.firstWhere((n) => n.id == 'j1');
        final j2 = map.nodes.firstWhere((n) => n.id == 'j2');

        // A mid-road stationary company: progress 0.5 between j1 and j2,
        // with a midRoadDestination set (now cleared upon split).
        final midRoadDest = RoadPosition(
          currentNodeId: j1.id,
          nextNodeId: j2.id,
          progress: 0.5,
        );
        final co = CompanyOnMap(
          id: 'player_co0',
          ownership: Ownership.player,
          currentNode: j1,
          progress: 0.5,
          midRoadDestination: midRoadDest,
          company: Company(
            composition: {UnitRole.warrior: 10},
          ),
        );

        final initialState = _emptyState().copyWith(companies: [co]);
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        // Perform split: keep 6 warriors, split off 4.
        await container.read(companyNotifierProvider.notifier).splitCompany(
              'player_co0',
              {UnitRole.warrior: 4},
            );

        final matchCompanies =
            container.read(matchNotifierProvider).valueOrNull?.companies ?? [];
        expect(matchCompanies.length, equals(2),
            reason: 'split produces exactly 2 companies');

        final kept = matchCompanies.firstWhere((c) => c.id == 'player_co0');
        final splitOff = matchCompanies.firstWhere((c) => c.id != 'player_co0');

        // Both halves must be at the same mid-road position.
        expect(kept.currentNode.id, equals('j1'));
        expect(kept.progress, equals(0.5));
        expect(splitOff.currentNode.id, equals('j1'));
        expect(splitOff.progress, equals(0.5));

        // midRoadDestination must be cleared — they are now stationary.
        expect(kept.midRoadDestination, isNull,
            reason: 'kept company midRoadDestination must be cleared');
        expect(splitOff.midRoadDestination, isNull,
            reason: 'splitOff company midRoadDestination must be cleared');

        // destination must also be null — they are stationary.
        expect(kept.destination, isNull);
        expect(splitOff.destination, isNull);
      },
    );

    test(
      'two mid-road companies at same (currentNode, progress) receive distinct offsets',
      () async {
        final map = GameMapFixture.build();
        final j1 = map.nodes.firstWhere((n) => n.id == 'j1');
        final j2 = map.nodes.firstWhere((n) => n.id == 'j2');

        final midRoadDest = RoadPosition(
          currentNodeId: j1.id,
          nextNodeId: j2.id,
          progress: 0.5,
        );
        final co = CompanyOnMap(
          id: 'player_co0',
          ownership: Ownership.player,
          currentNode: j1,
          progress: 0.5,
          midRoadDestination: midRoadDest,
          company: Company(composition: {UnitRole.warrior: 10}),
        );

        final initialState = _emptyState().copyWith(companies: [co]);
        final container = _makeContainer(initialState);
        addTearDown(container.dispose);

        await container.read(matchNotifierProvider.future);

        await container.read(companyNotifierProvider.notifier).splitCompany(
              'player_co0',
              {UnitRole.warrior: 4},
            );

        final matchCompanies =
            container.read(matchNotifierProvider).valueOrNull?.companies ?? [];
        expect(matchCompanies.length, equals(2));

        // Build the slot map and verify distinct offsets.
        final slotMap = _buildSlotMap(matchCompanies);
        final offA = _offsetForCompany(matchCompanies[0], slotMap);
        final offB = _offsetForCompany(matchCompanies[1], slotMap);

        expect(offA, isNot(equals(offB)),
            reason:
                'two mid-road companies at the same position must receive '
                'distinct slot offsets so each has its own tap target');
      },
    );

    test(
      'three mid-road companies at same position all receive distinct offsets',
      () async {
        final map = GameMapFixture.build();
        final j1 = map.nodes.firstWhere((n) => n.id == 'j1');

        // Build three mid-road stationary companies at j1, progress=0.5,
        // with no midRoadDestination (they are already stationary mid-road —
        // cleared after arrival).
        final companies = [
          CompanyOnMap(
            id: 'co_a',
            ownership: Ownership.player,
            currentNode: j1,
            progress: 0.5,
            company: Company(composition: {UnitRole.warrior: 5}),
          ),
          CompanyOnMap(
            id: 'co_b',
            ownership: Ownership.player,
            currentNode: j1,
            progress: 0.5,
            company: Company(composition: {UnitRole.warrior: 5}),
          ),
          CompanyOnMap(
            id: 'co_c',
            ownership: Ownership.player,
            currentNode: j1,
            progress: 0.5,
            company: Company(composition: {UnitRole.warrior: 5}),
          ),
        ];

        final slotMap = _buildSlotMap(companies);
        final offsets = companies
            .map((co) => _offsetForCompany(co, slotMap))
            .toList();

        // All three offsets must be distinct.
        expect(offsets[0], isNot(equals(offsets[1])));
        expect(offsets[0], isNot(equals(offsets[2])));
        expect(offsets[1], isNot(equals(offsets[2])));
      },
    );
  });
}
