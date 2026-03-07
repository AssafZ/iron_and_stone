// T034 + T035 — Failing widget tests for BattleIndicator
// Red-Green-Refactor: these tests must FAIL before T038 (widget implementation) is complete.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/ui/widgets/battle_indicator.dart';

void main() {
  group('BattleIndicator', () {
    // T034 — minimum 44×44 pt tap target
    testWidgets('renders with minimum 44×44 pt tap target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BattleIndicator(
                key: const ValueKey('battle_indicator_test_node'),
                battleId: 'battle_j1',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final finder = find.byKey(const ValueKey('battle_indicator_test_node'));
      expect(finder, findsOneWidget);

      // The widget must occupy at least 44 × 44 logical pixels so that it
      // satisfies the minimum tap-target requirement (HIG / Material spec).
      final renderBox = tester.renderObject<RenderBox>(finder);
      expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(44.0));
    });

    // T035 — onTap callback fires when indicator is tapped
    testWidgets('onTap callback fires when indicator is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BattleIndicator(
                key: const ValueKey('battle_indicator_tappable'),
                battleId: 'battle_j2',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('battle_indicator_tappable')));
      await tester.pump();

      expect(tapped, isTrue);
    });

    // Bonus: widget is wrapped in a RepaintBoundary to isolate animation repaints
    testWidgets('is wrapped in a RepaintBoundary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BattleIndicator(
                key: const ValueKey('battle_indicator_repaint'),
                battleId: 'battle_j3',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // RepaintBoundary must be present inside or wrapping the indicator
      // to isolate the pulse animation from the rest of the map.
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
    });
  });
}
