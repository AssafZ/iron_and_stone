// T064 — Widget tests for CastleScreen (no-garrison model).
// Castles have no garrison pool — soldiers live only in companies.

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
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/screens/castle_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
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

Match _minimalMatch() {
  final map = GameMap(
    nodes: [_playerCastleNode, _aiCastleNode],
    edges: [
      RoadEdge(from: _playerCastleNode, to: _aiCastleNode, length: 200),
      RoadEdge(from: _aiCastleNode, to: _playerCastleNode, length: 200),
    ],
  );
  return Match(
    map: map,
    humanPlayer: Ownership.player,
    phase: MatchPhase.playing,
  );
}

class _FakeMatchNotifier extends MatchNotifier {
  final MatchState _initial;
  _FakeMatchNotifier(this._initial);

  @override
  Future<MatchState> build() async => _initial;
}

Widget _buildScreen({
  Map<UnitRole, int> garrison = const {},
  List<CompanyOnMap> companies = const [],
}) {
  final castle = Castle(
    id: 'player_castle',
    ownership: Ownership.player,
    garrison: garrison,
  );
  final matchState = MatchState(
    match: _minimalMatch(),
    castles: [castle],
    companies: companies,
  );
  return ProviderScope(
    overrides: [
      matchNotifierProvider.overrideWith(() => _FakeMatchNotifier(matchState)),
    ],
    child: const MaterialApp(home: CastleScreen(castleId: 'player_castle')),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CastleScreen', () {
    testWidgets('displays Castle Stats section', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Castle Stats'), findsOneWidget);
    });

    testWidgets('displays Castle Cap label', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Cap'), findsWidgets);
    });

    testWidgets('displays growth rate information', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Growth Rate'), findsWidgets);
    });

    testWidgets('shows peasant count from stationed companies', (tester) async {
      final stationedCompany = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _playerCastleNode,
        company: Company(composition: {
          UnitRole.warrior: 3,
          UnitRole.peasant: 2,
        }),
      );
      await tester.pumpWidget(_buildScreen(companies: [stationedCompany]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Peasant'), findsWidgets);
    });

    testWidgets('shows companies section when companies are present', (tester) async {
      final company = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _playerCastleNode,
        company: Company(composition: {UnitRole.warrior: 5}),
      );
      await tester.pumpWidget(_buildScreen(companies: [company]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Companies here'), findsWidgets);
    });

    testWidgets('does not show DeploymentPanel', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deployment_panel')), findsNothing);
    });

    testWidgets('does not show a Garrison section', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // The header "Garrison" should not appear anywhere on screen.
      expect(find.text('Garrison'), findsNothing);
    });
  });
}
