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

      // Deploy a Company so the golden includes a marker.
      await tester.tap(find.byKey(const ValueKey('castle_node_player_castle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('deploy_company_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('company_marker_co0')), findsOneWidget);

      await screenMatchesGolden(tester, 'map_rendering_with_company');
    });

    testGoldens('map renders without companies (empty state)', (tester) async {
      await tester.pumpWidgetBuilder(
        const ProviderScope(child: MapScreen()),
        wrapper: materialAppWrapper(theme: ThemeData.light()),
        surfaceSize: const Size(800, 600),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'map_rendering_empty');
    });
  });
}
