// T059 — Golden test for BattleSideView widget layout.
// Captures a baseline screenshot of the melee-front / ranged-rear layout.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/ui/widgets/battle_side_view.dart';

void main() {
  group('BattleSideView golden', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('BattleSideView renders melee front / ranged rear layout',
        (tester) async {
      final companies = [
        Company(
          composition: {
            UnitRole.warrior: 5,
            UnitRole.knight: 2,
            UnitRole.archer: 3,
            UnitRole.catapult: 1,
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BattleSideView(
                companies: companies,
                label: 'Attackers',
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(BattleSideView),
        matchesGoldenFile('goldens/battle_side_view_attacker.png'),
      );
    }, tags: 'golden');

    testWidgets('BattleSideView renders empty ranged section when no ranged units',
        (tester) async {
      final companies = [
        Company(
          composition: {
            UnitRole.warrior: 10,
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BattleSideView(
                companies: companies,
                label: 'Defenders',
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(BattleSideView),
        matchesGoldenFile('goldens/battle_side_view_melee_only.png'),
      );
    }, tags: 'golden');
  });
}
