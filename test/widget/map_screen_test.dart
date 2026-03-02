// T031 + T037a — Failing widget tests for MapScreen
// Red-Green-Refactor: these tests must FAIL before implementation exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/ui/screens/map_screen.dart';

void main() {
  group('MapScreen', () {
    testWidgets('map loads with at least 2 castle node widgets visible',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MapScreen()),
        ),
      );
      // Allow async state to settle (new game initialisation).
      await tester.pumpAndSettle();

      // At minimum 2 castle nodes should be present in the widget tree.
      expect(find.byKey(const ValueKey('castle_node_player_castle')), findsOneWidget);
      expect(find.byKey(const ValueKey('castle_node_ai_castle')), findsOneWidget);
    });

    testWidgets('Company marker appears after deploy action', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the player castle to open deploy options.
      await tester.tap(find.byKey(const ValueKey('castle_node_player_castle')));
      await tester.pumpAndSettle();

      // Deploy button or deploy sheet should appear.
      expect(find.byKey(const ValueKey('deploy_company_button')), findsOneWidget);

      // Tap deploy.
      await tester.tap(find.byKey(const ValueKey('deploy_company_button')));
      await tester.pumpAndSettle();

      // A Company marker should now be visible.
      expect(find.byKey(const ValueKey('company_marker_co0')), findsOneWidget);
    });

    testWidgets('tapping a node sends movement intent to notifier',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Deploy a company first.
      await tester.tap(find.byKey(const ValueKey('castle_node_player_castle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('deploy_company_button')));
      await tester.pumpAndSettle();

      // Select the company marker (first tap).
      await tester.tap(find.byKey(const ValueKey('company_marker_co0')));
      await tester.pumpAndSettle();

      // Tap a destination node (second tap) — movement is assigned.
      await tester.tap(find.byKey(const ValueKey('junction_node_j1')));
      await tester.pumpAndSettle();

      // No crash is the primary assertion; marker must still be visible.
      expect(find.byKey(const ValueKey('company_marker_co0')), findsOneWidget);
    });

    // T037a — Two-step Company selection UX
    testWidgets(
        'first tap on Company marker sets selectedCompanyId; second tap on node assigns destination and clears selection',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Deploy a company.
      await tester.tap(find.byKey(const ValueKey('castle_node_player_castle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('deploy_company_button')));
      await tester.pumpAndSettle();

      // First tap: select company marker → selectedCompanyId should be set.
      await tester.tap(find.byKey(const ValueKey('company_marker_co0')));
      await tester.pumpAndSettle();

      // Selection indicator should appear.
      expect(find.byKey(const ValueKey('company_selected_co0')), findsOneWidget);

      // Second tap on destination node → assignment + clear selection.
      await tester.tap(find.byKey(const ValueKey('junction_node_j1')));
      await tester.pumpAndSettle();

      // Selection indicator should be gone.
      expect(find.byKey(const ValueKey('company_selected_co0')), findsNothing);
    });

    testWidgets(
        'tapping a node without a selected Company does not trigger movement',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Deploy a company.
      await tester.tap(find.byKey(const ValueKey('castle_node_player_castle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('deploy_company_button')));
      await tester.pumpAndSettle();

      // Tap a node WITHOUT selecting a company first — no crash, no movement.
      await tester.tap(find.byKey(const ValueKey('junction_node_j1')));
      await tester.pumpAndSettle();

      // Company is still at player castle (no movement assigned).
      expect(find.byKey(const ValueKey('company_marker_co0')), findsOneWidget);
    });
  });
}
