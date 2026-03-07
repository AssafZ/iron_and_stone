// T014 — Failing widget tests for road tap → setMidRoadDestination (US1)
// Red-Green-Refactor: these tests must FAIL before T017 / T018 implementation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
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
}
