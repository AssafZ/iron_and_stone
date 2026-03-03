// T043 — Golden test for map rendering
// Captures baseline screenshots for RepaintBoundary boundary validation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:iron_and_stone/ui/screens/map_screen.dart';

void main() {
  group('MapScreen golden', () {
    setUpAll(() async {
      await loadAppFonts();
    });

    testGoldens('map renders two castle nodes and one Company marker',
        (tester) async {
      await tester.pumpWidgetBuilder(
        const ProviderScope(child: MapScreen()),
        wrapper: materialAppWrapper(
          theme: ThemeData.light(),
        ),
        surfaceSize: const Size(800, 600),
      );

      // Settle initial async state.
      await tester.pumpAndSettle();

      // Verify castle nodes are present before capturing golden.
      expect(find.byKey(const ValueKey('castle_node_player_castle')), findsOneWidget);
      expect(find.byKey(const ValueKey('castle_node_ai_castle')), findsOneWidget);

      // Game starts with a player company already placed — no deploy step needed.
      expect(find.byKey(const ValueKey('company_marker_player_co0')), findsOneWidget);

      await screenMatchesGolden(tester, 'map_rendering_with_company');
    });

    testGoldens('map renders with starting companies visible', (tester) async {
      await tester.pumpWidgetBuilder(
        const ProviderScope(child: MapScreen()),
        wrapper: materialAppWrapper(theme: ThemeData.light()),
        surfaceSize: const Size(800, 600),
      );
      await tester.pumpAndSettle();

      // Both player and AI companies are on the map from game start.
      expect(find.byKey(const ValueKey('company_marker_player_co0')), findsOneWidget);

      await screenMatchesGolden(tester, 'map_rendering_empty');
    });
  });
}
