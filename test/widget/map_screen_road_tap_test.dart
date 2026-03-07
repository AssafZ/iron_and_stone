// T014 — Failing widget tests for road tap → setMidRoadDestination (US1)
// Red-Green-Refactor: these tests must FAIL before T017 / T018 implementation.
// T031 [US5] — Splitting a mid-road company produces two markers at distinct
// canvas positions, each independently tappable.
// T036 [US6] — Proximity merge dialog appears when selected company is within
// kProximityMergeThreshold of tapped friendly company; no dialog when beyond.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/ui/screens/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Converts a canvas-space point to widget-tree (screen) coordinates.
///
/// The [InteractiveViewer] starts with an identity transform in tests (no
/// _fitMapToScreen has been called), so canvas coords ≈ widget coords
/// relative to the top-left of the InteractiveViewer child.
///
/// We use [tester.getTopLeft] on a known reference widget if needed.
///
/// Canvas constants from map_screen.dart:
///   _scale  = 1.2
///   _offsetX = 50.0
///   _offsetY = 180.0
///
/// Node canvas positions:
///   player_castle: (0*1.2+50, 0*1.2+180) = (50.0, 180.0)
///   j1:            (100*1.2+50, 0*1.2+180) = (170.0, 180.0)
///   j2:            (200*1.2+50, 50*1.2+180) = (290.0, 240.0)
///
/// Road segment player_castle → j1 runs from (50, 180) to (170, 180).
/// Mid-point in canvas space = (110, 180).
///
/// In widget tests the InteractiveViewer SizedBox is the top-level scrollable
/// area.  We locate the canvas position by finding the SizedBox with the
/// canvas dimensions and computing an offset within it.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'settings.firstRunHintShown': true,
    });
  });

  group('MapScreen road tap (T014)', () {
    // -------------------------------------------------------------------------
    // (a) Tap canvas point on road segment → company midRoadDestination set
    // -------------------------------------------------------------------------
    testWidgets(
        '(a) tapping a point on a road segment sets midRoadDestination on '
        'the selected company', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Select the player company first.
      final playerMarker =
          find.byKey(const ValueKey('company_marker_player_co0'));
      expect(playerMarker, findsOneWidget);
      await tester.tap(playerMarker);
      await tester.pumpAndSettle();

      // The move-mode banner must be visible (company selected, stationary).
      expect(find.byKey(const ValueKey('move_hint_banner')), findsOneWidget);

      // Now tap the canvas at a point that lies on the road between
      // player_castle and j1.
      //
      // We derive the tap position from the rendered positions of the two
      // node widgets (which reflect any InteractiveViewer transformation).
      // The midpoint between them is guaranteed to be on the road segment.
      final pcFinder = find.byKey(const ValueKey('castle_node_player_castle'));
      final j1Finder = find.byKey(const ValueKey('junction_node_j1'));
      expect(pcFinder, findsOneWidget);
      expect(j1Finder, findsOneWidget);

      final pcCenter = tester.getCenter(pcFinder);
      final j1Center = tester.getCenter(j1Finder);

      // Tap the midpoint between the two nodes — guaranteed to be on-road.
      final roadMidPoint = Offset(
        (pcCenter.dx + j1Center.dx) / 2,
        (pcCenter.dy + j1Center.dy) / 2,
      );
      await tester.tapAt(roadMidPoint);
      await tester.pumpAndSettle();

      // Read the company state to verify midRoadDestination was set.
      final element = tester.element(find.byType(MapScreen));
      final container = ProviderScope.containerOf(element);
      final matchState = container.read(matchNotifierProvider).valueOrNull;
      expect(matchState, isNotNull);

      final company = matchState!.companies
          .where((c) => c.id == 'player_co0')
          .firstOrNull;
      expect(company, isNotNull);
      expect(
        company!.midRoadDestination,
        isNotNull,
        reason:
            'Tapping a road point should set midRoadDestination on the selected company',
      );
    });

    // -------------------------------------------------------------------------
    // (b) Tap off all road segments → company does not move
    // -------------------------------------------------------------------------
    testWidgets(
        '(b) tapping a canvas point off all road segments does not set '
        'midRoadDestination', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Select the player company.
      final playerMarker =
          find.byKey(const ValueKey('company_marker_player_co0'));
      await tester.tap(playerMarker);
      await tester.pumpAndSettle();

      // Tap a point that is definitely off all road segments.
      // We find the GestureDetector canvas and tap near its bottom-right
      // corner — roads are clustered in the upper-left of the canvas, so
      // the bottom-right is clear.
      final canvasFinder = find.byKey(const ValueKey('map_canvas_gesture'));
      expect(canvasFinder, findsOneWidget);
      final canvasBottomRight = tester.getBottomRight(canvasFinder);
      // Tap 20 pixels in from the bottom-right corner.
      await tester.tapAt(canvasBottomRight - const Offset(20.0, 20.0));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(MapScreen));
      final container = ProviderScope.containerOf(element);
      final matchState = container.read(matchNotifierProvider).valueOrNull;
      expect(matchState, isNotNull);

      final company = matchState!.companies
          .where((c) => c.id == 'player_co0')
          .firstOrNull;
      expect(company, isNotNull);
      expect(
        company!.midRoadDestination,
        isNull,
        reason:
            'Tapping off-road should NOT set midRoadDestination',
      );
      expect(
        company.destination,
        isNull,
        reason:
            'Tapping off-road should NOT set a node destination either',
      );
    });

    // -------------------------------------------------------------------------
    // (c) Move banner text contains "road point"
    // -------------------------------------------------------------------------
    testWidgets(
        '(c) move-mode banner text contains "road point" when a company is '
        'selected and stationary', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Select the player company to reveal the banner.
      final playerMarker =
          find.byKey(const ValueKey('company_marker_player_co0'));
      await tester.tap(playerMarker);
      await tester.pumpAndSettle();

      // Banner must contain "road point".
      expect(
        find.textContaining('road point'),
        findsOneWidget,
        reason:
            'Move-mode banner must say "road point" to guide the player to tap roads',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // T031 [US5]: splitting a mid-road company — two markers, distinct positions
  // ---------------------------------------------------------------------------

  group('T031 [US5]: split mid-road company produces two distinct, tappable markers',
      () {
    testWidgets(
      '(a) after split two company markers appear at distinct canvas positions',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matchNotifierProvider.overrideWith(_FakeMatchNotifier.new),
            ],
            child: const MaterialApp(home: MapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // The mid-road player company marker must be present.
        final markerFinder =
            find.byKey(const ValueKey('company_marker_mid_co'));
        expect(markerFinder, findsOneWidget,
            reason: 'mid-road company marker must be visible before split');

        // Long-press to open the split slider.
        await tester.longPress(markerFinder);
        await tester.pumpAndSettle();

        // Assign at least 1 soldier to Company B by tapping the increment
        // button for the warrior role (the only role in our test company).
        final incButton = find.byKey(const ValueKey('split_inc_warrior'));
        expect(incButton, findsOneWidget,
            reason: 'warrior increment button must be present');
        await tester.tap(incButton);
        await tester.pumpAndSettle();

        // Confirm the split (split_confirm_button is now enabled).
        final confirmButton =
            find.byKey(const ValueKey('split_confirm_button'));
        expect(confirmButton, findsOneWidget,
            reason: 'split confirm button must be present');
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        // After the split there must be exactly 2 company markers.
        // Use a general search for all company_marker_ keys.
        final markerWidgets = find.byWidgetPredicate(
          (w) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith('company_marker_'),
        );
        expect(markerWidgets, findsNWidgets(2),
            reason: 'split must produce exactly 2 company markers');

        // Verify the two markers are at distinct canvas positions.
        final markerList = tester.widgetList(markerWidgets).toList();
        final positions = markerList
            .map((w) => tester.getCenter(find.byWidget(w)))
            .toList();

        expect(positions.length, equals(2));
        expect(positions[0], isNot(equals(positions[1])),
            reason:
                'two mid-road companies at the same position must appear at '
                'distinct canvas coordinates so each has its own tap target');
      },
    );

    testWidgets(
      '(b) each of the two post-split markers responds to tap independently',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matchNotifierProvider.overrideWith(_FakeMatchNotifier.new),
            ],
            child: const MaterialApp(home: MapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Long-press and confirm split (assign 1 warrior to Company B first).
        await tester.longPress(
            find.byKey(const ValueKey('company_marker_mid_co')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('split_inc_warrior')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('split_confirm_button')));
        await tester.pumpAndSettle();

        // Find both markers.
        final markerWidgets = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              (w.key as ValueKey).value.toString().startsWith('company_marker_'),
        );
        expect(markerWidgets, findsNWidgets(2));

        // Collect the ValueKey values for both markers.
        final markerKeys = tester
            .widgetList(markerWidgets)
            .map((w) => (w.key as ValueKey).value as String)
            .toList()
          ..sort();

        // Tap marker 0 → it becomes selected.
        await tester.tap(find.byKey(ValueKey(markerKeys[0])));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(MapScreen));
        final container = ProviderScope.containerOf(element);
        final companyState =
            container.read(companyNotifierProvider).valueOrNull;
        expect(companyState?.selectedCompanyId, isNotNull,
            reason: 'tapping the first marker must select it');

        final firstSelectedId = companyState!.selectedCompanyId!;

        // Deselect and tap marker 1.
        container.read(companyNotifierProvider.notifier).clearSelection();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ValueKey(markerKeys[1])));
        await tester.pumpAndSettle();

        final companyState2 =
            container.read(companyNotifierProvider).valueOrNull;
        final secondSelectedId = companyState2?.selectedCompanyId;
        expect(secondSelectedId, isNotNull,
            reason: 'tapping the second marker must select it');
        expect(secondSelectedId, isNot(equals(firstSelectedId)),
            reason:
                'each marker must correspond to a different company — '
                'tapping each must select a different company');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // T036 [US6]: Proximity merge dialog
  // ---------------------------------------------------------------------------
  group('T036 [US6]: proximity merge dialog', () {
    testWidgets(
      '(a) select company A then tap company B (25 units away) → merge dialog appears',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matchNotifierProvider.overrideWith(_FakeProximityMatchNotifier.new),
            ],
            child: const MaterialApp(home: MapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Select company A first.
        final markerA = find.byKey(const ValueKey('company_marker_co_a'));
        expect(markerA, findsOneWidget,
            reason: 'Company A marker must be visible');
        await tester.tap(markerA);
        await tester.pumpAndSettle();

        // Now tap company B (25 units from A — within threshold).
        final markerB = find.byKey(const ValueKey('company_marker_co_b'));
        expect(markerB, findsOneWidget,
            reason: 'Company B marker must be visible');
        await tester.tap(markerB);
        await tester.pumpAndSettle();

        // The merge dialog must appear.
        expect(
          find.text('Merge Companies?'),
          findsOneWidget,
          reason:
              'Merge dialog must appear when tapping a friendly company '
              'within kProximityMergeThreshold',
        );
      },
    );

    testWidgets(
      '(b) select company A then tap company C (55 units away) → no dialog',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matchNotifierProvider.overrideWith(_FakeProximityMatchNotifier.new),
            ],
            child: const MaterialApp(home: MapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Select company A first.
        final markerA = find.byKey(const ValueKey('company_marker_co_a'));
        expect(markerA, findsOneWidget,
            reason: 'Company A marker must be visible');
        await tester.tap(markerA);
        await tester.pumpAndSettle();

        // Now tap company C (55 units from A — beyond threshold).
        final markerC = find.byKey(const ValueKey('company_marker_co_c'));
        expect(markerC, findsOneWidget,
            reason: 'Company C marker must be visible');
        await tester.tap(markerC);
        await tester.pumpAndSettle();

        // The merge dialog must NOT appear.
        expect(
          find.text('Merge Companies?'),
          findsNothing,
          reason:
              'Merge dialog must NOT appear when tapping a friendly company '
              'beyond kProximityMergeThreshold',
        );
      },
    );
  });
}


class _FakeMatchNotifier extends MatchNotifier {
  @override
  Future<MatchState> build() async {
    final map = GameMapFixture.build();
    final j1 = map.nodes.firstWhere((n) => n.id == 'j1');

    // A mid-road stationary company: progress 0.5 between player_castle and
    // j1, no destination, no midRoadDestination (arrived and stopped).
    final midRoadCo = CompanyOnMap(
      id: 'mid_co',
      ownership: Ownership.player,
      currentNode: j1,
      progress: 0.5,
      company: Company(composition: {UnitRole.warrior: 10}),
    );

    return MatchState(
      match: Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      ),
      castles: const [],
      companies: [midRoadCo],
      activeBattles: const [],
    );
  }
}

// ---------------------------------------------------------------------------
// Fake MatchNotifier for T036: seeds two mid-road companies at known positions
// ---------------------------------------------------------------------------

/// Seeds three player companies on the player_castle→j1 segment (length 100).
/// All companies have midRoadDestination set so their RoadPosition is known.
///
/// Company A: player_castle→j1 at progress=0.25 (25 units in).
/// Company B: player_castle→j1 at progress=0.50 (50 units in → 25 units from A → within threshold=30).
/// Company C: player_castle→j1 at progress=0.80 (80 units in → 55 units from A → beyond threshold=30).
class _FakeProximityMatchNotifier extends MatchNotifier {
  @override
  Future<MatchState> build() async {
    final map = GameMapFixture.build();
    final playerCastle =
        map.nodes.firstWhere((n) => n.id == GameMapFixture.playerCastleId);

    final segA = RoadPosition(
      currentNodeId: GameMapFixture.playerCastleId,
      nextNodeId: 'j1',
      progress: 0.25,
    );
    final segB = RoadPosition(
      currentNodeId: GameMapFixture.playerCastleId,
      nextNodeId: 'j1',
      progress: 0.50,
    );
    final segC = RoadPosition(
      currentNodeId: GameMapFixture.playerCastleId,
      nextNodeId: 'j1',
      progress: 0.80,
    );

    // Company A — the one we'll select first.
    final coA = CompanyOnMap(
      id: 'co_a',
      ownership: Ownership.player,
      currentNode: playerCastle,
      progress: 0.25,
      midRoadDestination: segA,
      company: Company(composition: {UnitRole.warrior: 5}),
    );

    // Company B — 25 units from A on the same segment (within threshold=30).
    final coB = CompanyOnMap(
      id: 'co_b',
      ownership: Ownership.player,
      currentNode: playerCastle,
      progress: 0.50,
      midRoadDestination: segB,
      company: Company(composition: {UnitRole.warrior: 5}),
    );

    // Company C — 55 units from A on the same segment (beyond threshold=30).
    final coC = CompanyOnMap(
      id: 'co_c',
      ownership: Ownership.player,
      currentNode: playerCastle,
      progress: 0.80,
      midRoadDestination: segC,
      company: Company(composition: {UnitRole.warrior: 5}),
    );

    return MatchState(
      match: Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      ),
      castles: const [],
      companies: [coA, coB, coC],
      activeBattles: const [],
    );
  }
}
