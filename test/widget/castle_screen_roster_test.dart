// Phase 4 — Widget tests for castle garrison roster and enemy read-only summary (US2)
// TDD: tests are written BEFORE implementation and must FAIL first.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/screens/castle_screen.dart';

// ---------------------------------------------------------------------------
// Map & castle fixtures
// ---------------------------------------------------------------------------

const _playerCastleNode = CastleNode(
  id: 'player_castle',
  x: 0,
  y: 0,
  ownership: Ownership.player,
);
const _aiCastleNode = CastleNode(
  id: 'ai_castle',
  x: 200,
  y: 0,
  ownership: Ownership.ai,
);
const _junction = RoadJunctionNode(id: 'j1', x: 100, y: 0);

Match _minimalMatch() {
  final map = GameMap(
    nodes: [_playerCastleNode, _aiCastleNode, _junction],
    edges: [
      RoadEdge(from: _playerCastleNode, to: _junction, length: 100),
      RoadEdge(from: _junction, to: _playerCastleNode, length: 100),
      RoadEdge(from: _aiCastleNode, to: _junction, length: 100),
      RoadEdge(from: _junction, to: _aiCastleNode, length: 100),
    ],
  );
  return Match(
    map: map,
    humanPlayer: Ownership.player,
    phase: MatchPhase.playing,
  );
}

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

class _FakeMatchNotifier extends MatchNotifier {
  final MatchState _initial;
  _FakeMatchNotifier(this._initial);

  @override
  Future<MatchState> build() async => _initial;
}

class _FakeCompanyNotifier extends CompanyNotifier {
  final CompanyListState _initial;
  String? lastSelectedId;

  _FakeCompanyNotifier(this._initial);

  @override
  Future<CompanyListState> build() async => _initial;

  @override
  void selectCompany(String id) {
    lastSelectedId = id;
    final current = state.valueOrNull ?? const CompanyListState();
    state = AsyncData(current.copyWith(selectedCompanyId: id));
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Build the CastleScreen for the player's castle with the supplied companies.
Widget _buildPlayerCastleScreen({
  required List<CompanyOnMap> companies,
  _FakeCompanyNotifier? companyNotifier,
}) {
  final castle = Castle(
    id: 'player_castle',
    ownership: Ownership.player,
    garrison: const {},
  );
  final matchState = MatchState(
    match: _minimalMatch(),
    castles: [castle],
    companies: companies,
  );

  final companyState = CompanyListState(companies: companies);
  final fakeCompany = companyNotifier ?? _FakeCompanyNotifier(companyState);

  return ProviderScope(
    overrides: [
      matchNotifierProvider.overrideWith(() => _FakeMatchNotifier(matchState)),
      companyNotifierProvider.overrideWith(() => fakeCompany),
    ],
    child: const MaterialApp(home: CastleScreen(castleId: 'player_castle')),
  );
}

/// Build the CastleScreen for the AI castle with the supplied companies.
Widget _buildEnemyCastleScreen({
  required List<CompanyOnMap> companies,
}) {
  final castle = Castle(
    id: 'ai_castle',
    ownership: Ownership.ai,
    garrison: const {},
  );
  final matchState = MatchState(
    match: _minimalMatch(),
    castles: [castle],
    companies: companies,
  );
  final companyState = CompanyListState(companies: companies);

  return ProviderScope(
    overrides: [
      matchNotifierProvider.overrideWith(() => _FakeMatchNotifier(matchState)),
      companyNotifierProvider.overrideWith(
        () => _FakeCompanyNotifier(companyState),
      ),
    ],
    child: const MaterialApp(home: CastleScreen(castleId: 'ai_castle')),
  );
}

CompanyOnMap _makePlayerCompany({
  required String id,
  required MapNode currentNode,
  MapNode? destination,
  int soldiers = 10,
}) =>
    CompanyOnMap(
      id: id,
      ownership: Ownership.player,
      currentNode: currentNode,
      destination: destination,
      company: Company(composition: {UnitRole.warrior: soldiers}),
    );

CompanyOnMap _makeAiCompany({
  required String id,
  required MapNode currentNode,
  int soldiers = 8,
}) =>
    CompanyOnMap(
      id: id,
      ownership: Ownership.ai,
      currentNode: currentNode,
      company: Company(composition: {UnitRole.warrior: soldiers}),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Phase 4 — US2 Castle Roster', () {
    // -----------------------------------------------------------------------
    // T031: player castle with two garrisoned companies shows a roster listing
    // both.
    // -----------------------------------------------------------------------
    testWidgets(
      'T031: tapping a player castle with two garrisoned companies shows a '
      'roster widget listing both companies',
      (tester) async {
        final coA = _makePlayerCompany(
          id: 'co_a',
          currentNode: _playerCastleNode,
          soldiers: 10,
        );
        final coB = _makePlayerCompany(
          id: 'co_b',
          currentNode: _playerCastleNode,
          soldiers: 20,
        );

        await tester.pumpWidget(
          _buildPlayerCastleScreen(companies: [coA, coB]),
        );
        await tester.pumpAndSettle();

        // A roster section header must be visible.
        expect(find.byKey(const ValueKey('castle_roster_card')), findsOneWidget);

        // Each company must have its own individually tappable row.
        expect(find.byKey(const ValueKey('roster_row_co_a')), findsOneWidget);
        expect(find.byKey(const ValueKey('roster_row_co_b')), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // T032: selecting a roster row triggers selection for that company only.
    // -----------------------------------------------------------------------
    testWidgets(
      'T032: tapping a roster row selects that company and not the other',
      (tester) async {
        final coA = _makePlayerCompany(
          id: 'co_a',
          currentNode: _playerCastleNode,
          soldiers: 10,
        );
        final coB = _makePlayerCompany(
          id: 'co_b',
          currentNode: _playerCastleNode,
          soldiers: 20,
        );

        final fakeNotifier = _FakeCompanyNotifier(
          CompanyListState(companies: [coA, coB]),
        );

        await tester.pumpWidget(
          _buildPlayerCastleScreen(
            companies: [coA, coB],
            companyNotifier: fakeNotifier,
          ),
        );
        await tester.pumpAndSettle();

        // Tap the roster row for co_b.
        await tester.tap(find.byKey(const ValueKey('roster_row_co_b')));
        await tester.pumpAndSettle();

        // co_b must be selected; co_a must NOT be selected.
        expect(fakeNotifier.lastSelectedId, equals('co_b'));
        expect(fakeNotifier.lastSelectedId, isNot(equals('co_a')));
      },
    );

    // -----------------------------------------------------------------------
    // T033: opening the castle screen auto-selects the first player company.
    // -----------------------------------------------------------------------
    testWidgets(
      'T033: opening the castle screen auto-selects the first player company '
      'so the map always shows the correct unit on top',
      (tester) async {
        final coA = _makePlayerCompany(
          id: 'co_a',
          currentNode: _playerCastleNode,
          soldiers: 10,
        );

        final fakeNotifier = _FakeCompanyNotifier(
          CompanyListState(companies: [coA]),
        );

        await tester.pumpWidget(
          _buildPlayerCastleScreen(
            companies: [coA],
            companyNotifier: fakeNotifier,
          ),
        );
        await tester.pumpAndSettle();

        // The first company should be auto-selected on entry.
        expect(fakeNotifier.lastSelectedId, equals('co_a'));
      },
    );

    // -----------------------------------------------------------------------
    // T034: enemy castle shows read-only defender total, no roster, no actions.
    // -----------------------------------------------------------------------
    testWidgets(
      'T034: tapping an enemy castle shows a read-only summary with total '
      'soldier count and no action buttons',
      (tester) async {
        final aiCoA = _makeAiCompany(
          id: 'ai_co_a',
          currentNode: _aiCastleNode,
          soldiers: 15,
        );
        final aiCoB = _makeAiCompany(
          id: 'ai_co_b',
          currentNode: _aiCastleNode,
          soldiers: 17,
        );

        await tester.pumpWidget(
          _buildEnemyCastleScreen(companies: [aiCoA, aiCoB]),
        );
        await tester.pumpAndSettle();

        // Must show the defender summary with the exact total (15 + 17 = 32).
        expect(
          find.byKey(const ValueKey('enemy_castle_defender_summary')),
          findsOneWidget,
        );
        expect(find.textContaining('32'), findsWidgets);

        // Must NOT show the roster card (no individual rows).
        expect(find.byKey(const ValueKey('castle_roster_card')), findsNothing);

        // Must NOT show a deploy or manage button.
        expect(find.textContaining('Manage'), findsNothing);
        expect(find.textContaining('Deploy'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // T035: garrisoned (stationary) and defending (in-transit) companies are
    // visually distinguishable in the roster.
    // -----------------------------------------------------------------------
    testWidgets(
      'T035: garrisoned (stationary) and defending (in-transit) companies '
      'are visually distinguishable in the roster',
      (tester) async {
        // co_stationary has no destination → garrisoned.
        final coStationary = _makePlayerCompany(
          id: 'co_stationary',
          currentNode: _playerCastleNode,
          soldiers: 10,
        );
        // co_defending is moving but at the castle node → defending.
        final coDefending = _makePlayerCompany(
          id: 'co_defending',
          currentNode: _playerCastleNode,
          destination: _junction,
          soldiers: 8,
        );

        await tester.pumpWidget(
          _buildPlayerCastleScreen(companies: [coStationary, coDefending]),
        );
        await tester.pumpAndSettle();

        // Both rows must be present.
        expect(
          find.byKey(const ValueKey('roster_row_co_stationary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('roster_row_co_defending')),
          findsOneWidget,
        );

        // The garrisoned row must show a 'Garrisoned' label.
        expect(find.textContaining('Garrisoned'), findsWidgets);

        // The defending/in-transit row must show a 'Defending' label.
        expect(find.textContaining('Defending'), findsWidgets);
      },
    );
  });
}
