// T074 — Failing widget tests for SplitSlider widget
// Red-Green-Refactor: these tests FAIL before SplitSlider implementation exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/ui/widgets/split_slider.dart';

void main() {
  const node = RoadJunctionNode(id: 'j1', x: 0, y: 0);

  CompanyOnMap makeCompany({required Map<UnitRole, int> composition}) {
    return CompanyOnMap(
      id: 'co1',
      company: Company(composition: composition),
      ownership: Ownership.player,
      currentNode: node,
    );
  }

  group('SplitSlider widget', () {
    testWidgets('renders role stepper rows for each role in the Company',
        (tester) async {
      final company = makeCompany(
        composition: {UnitRole.warrior: 10, UnitRole.archer: 5},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SplitSlider(
                company: company,
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );

      // Both role rows should be visible.
      expect(find.byKey(const ValueKey('split_row_warrior')), findsOneWidget);
      expect(find.byKey(const ValueKey('split_row_archer')), findsOneWidget);
    });

    testWidgets('live preview shows correct Company A and Company B counts',
        (tester) async {
      final company = makeCompany(composition: {UnitRole.warrior: 10});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SplitSlider(
                company: company,
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );

      // Initially split is 0 — Company A = 10, Company B = 0.
      expect(find.byKey(const ValueKey('split_preview_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('split_preview_b')), findsOneWidget);
      expect(find.text('Company A: 10'), findsOneWidget);
      expect(find.text('Company B: 0'), findsOneWidget);
    });

    testWidgets('incrementing split count updates live preview', (tester) async {
      final company = makeCompany(composition: {UnitRole.warrior: 10});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SplitSlider(
                company: company,
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap the increment (+) button for warriors to split off 1 warrior.
      await tester.tap(find.byKey(const ValueKey('split_inc_warrior')));
      await tester.pump();

      // Company A = 9, Company B = 1.
      expect(find.text('Company A: 9'), findsOneWidget);
      expect(find.text('Company B: 1'), findsOneWidget);
    });

    testWidgets('Confirm Split button is disabled when split count is 0',
        (tester) async {
      final company = makeCompany(composition: {UnitRole.warrior: 10});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SplitSlider(
                company: company,
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );

      final confirmButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('split_confirm_button')),
      );
      expect(confirmButton.onPressed, isNull);
    });

    testWidgets(
        'Confirm Split button dispatches correct split composition on tap',
        (tester) async {
      final company = makeCompany(
        composition: {UnitRole.warrior: 10, UnitRole.archer: 5},
      );

      Map<UnitRole, int>? capturedSplit;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SplitSlider(
                company: company,
                onConfirm: (split) {
                  capturedSplit = split;
                },
              ),
            ),
          ),
        ),
      );

      // Increment warriors split to 3.
      await tester.tap(find.byKey(const ValueKey('split_inc_warrior')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('split_inc_warrior')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('split_inc_warrior')));
      await tester.pump();

      // Confirm split.
      await tester.tap(find.byKey(const ValueKey('split_confirm_button')));
      await tester.pump();

      expect(capturedSplit, isNotNull);
      expect(capturedSplit![UnitRole.warrior], 3);
    });

    testWidgets(
        'decrement button is disabled when split count for role is already 0',
        (tester) async {
      final company = makeCompany(composition: {UnitRole.warrior: 10});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SplitSlider(
                company: company,
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );

      final decButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('split_dec_warrior')),
      );
      expect(decButton.onPressed, isNull);
    });
  });
}
