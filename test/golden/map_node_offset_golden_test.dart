// Phase 3 — Golden tests for company marker offset slots (US1)
// TDD: tests are written BEFORE implementation and must FAIL first.
// Run with --update-goldens on first pass after implementation is complete.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/node_occupancy.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/ui/widgets/company_marker.dart';

// ---------------------------------------------------------------------------
// Slot offset table — mirrors the intended _kSlotOffsets in map_screen.dart
// ---------------------------------------------------------------------------

const _kSlotOffsets = [
  (0.0, 0.0),     // slot 0 — centre
  (20.0, 0.0),    // slot 1 — right
  (-20.0, 0.0),   // slot 2 — left
  (0.0, -20.0),   // slot 3 — above
  (0.0, 20.0),    // slot 4 — below
  (-20.0, -20.0),
  (20.0, -20.0),
  (-20.0, 20.0),
  (20.0, 20.0),
];

const _junction = RoadJunctionNode(id: 'j1', x: 150, y: 0);
const _kMarkerSize = 44.0;
const _cx = 200.0;
const _cy = 200.0;

CompanyOnMap _makeCompany({
  required String id,
  Ownership ownership = Ownership.player,
}) =>
    CompanyOnMap(
      company: Company(composition: {UnitRole.warrior: 5}),
      id: id,
      ownership: ownership,
      currentNode: _junction,
    );

(double, double) _offsetForSlot(int slot) {
  if (slot >= _kSlotOffsets.length) return (0.0, 0.0);
  return _kSlotOffsets[slot];
}

/// Renders [n] company markers at their slot positions in a fixed-size canvas.
Widget _buildSlotScene(List<CompanyOnMap> companies, Map<String, NodeOccupancy> occupancy) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFFF5E6C8),
      body: SizedBox(
        width: 400,
        height: 400,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Reference dot at node centre
            Positioned(
              left: _cx - 4,
              top: _cy - 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            for (final co in companies)
              Builder(builder: (_) {
                final occ = occupancy[co.currentNode.id];
                final slot = occ?.slotIndex(co.id) ?? 0;
                final (ox, oy) = _offsetForSlot(slot);
                return Positioned(
                  key: ValueKey('positioned_${co.id}'),
                  left: _cx + ox - _kMarkerSize / 2,
                  top: _cy + oy - _kMarkerSize / 2,
                  child: SizedBox(
                    width: _kMarkerSize,
                    height: _kMarkerSize,
                    child: CompanyMarker(
                      key: ValueKey('marker_${co.id}'),
                      company: co,
                      x: _cx + ox,
                      y: _cy + oy,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  // -------------------------------------------------------------------------
  // T020: 2 companies — slot 0 (centre) and slot 1 (right)
  // -------------------------------------------------------------------------

  group('T020 — golden: 2 companies at same node', () {
    testGoldens('slot-0 and slot-1 are visually distinct', (tester) async {
      final coA = _makeCompany(id: 'co_a');
      final coB = _makeCompany(id: 'co_b', ownership: Ownership.ai);

      final occupancy = {
        _junction.id: NodeOccupancy(nodeId: _junction.id, orderedIds: ['co_a', 'co_b']),
      };

      await tester.pumpWidgetBuilder(
        _buildSlotScene([coA, coB], occupancy),
        surfaceSize: const Size(400, 400),
      );
      await tester.pump();

      // Verify distinct positions before capturing golden.
      final posA = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_a')));
      final posB = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_b')));
      expect(posA == posB, isFalse, reason: 'Slot 0 and slot 1 must be at different positions');

      // Slot 0 = centre (offset 0,0) → left = cx - 22 = 178, top = cy - 22 = 178
      expect(posA.dx, closeTo(_cx - _kMarkerSize / 2, 1.0));
      expect(posA.dy, closeTo(_cy - _kMarkerSize / 2, 1.0));
      // Slot 1 = right (+20, 0) → left = cx + 20 - 22 = 198
      expect(posB.dx, closeTo(_cx + 20 - _kMarkerSize / 2, 1.0));
      expect(posB.dy, closeTo(_cy - _kMarkerSize / 2, 1.0));

      await screenMatchesGolden(tester, 'map_node_offset_2_companies');
    });
  });

  // -------------------------------------------------------------------------
  // T021: 3 companies — slot 0, 1, 2
  // -------------------------------------------------------------------------

  group('T021 — golden: 3 companies at same node', () {
    testGoldens('slot-0, slot-1, slot-2 are at correct positions', (tester) async {
      final coA = _makeCompany(id: 'co_a');
      final coB = _makeCompany(id: 'co_b', ownership: Ownership.ai);
      final coC = _makeCompany(id: 'co_c');

      final occupancy = {
        _junction.id: NodeOccupancy(
          nodeId: _junction.id,
          orderedIds: ['co_a', 'co_b', 'co_c'],
        ),
      };

      await tester.pumpWidgetBuilder(
        _buildSlotScene([coA, coB, coC], occupancy),
        surfaceSize: const Size(400, 400),
      );
      await tester.pump();

      final posA = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_a')));
      final posB = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_b')));
      final posC = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_c')));

      // All three positions must be distinct.
      expect(posA == posB, isFalse);
      expect(posA == posC, isFalse);
      expect(posB == posC, isFalse);

      // Slot 0 → (0,0), slot 1 → (+20,0), slot 2 → (-20,0)
      expect(posA.dx, closeTo(_cx - _kMarkerSize / 2, 1.0));
      expect(posB.dx, closeTo(_cx + 20 - _kMarkerSize / 2, 1.0));
      expect(posC.dx, closeTo(_cx - 20 - _kMarkerSize / 2, 1.0));

      await screenMatchesGolden(tester, 'map_node_offset_3_companies');
    });
  });

  // -------------------------------------------------------------------------
  // T022: 5 companies — all 5 slot positions
  // -------------------------------------------------------------------------

  group('T022 — golden: 5 companies at same node', () {
    testGoldens('all 5 slot positions are distinct', (tester) async {
      final companies = [
        _makeCompany(id: 'co_0'),
        _makeCompany(id: 'co_1', ownership: Ownership.ai),
        _makeCompany(id: 'co_2'),
        _makeCompany(id: 'co_3', ownership: Ownership.ai),
        _makeCompany(id: 'co_4'),
      ];

      final occupancy = {
        _junction.id: NodeOccupancy(
          nodeId: _junction.id,
          orderedIds: ['co_0', 'co_1', 'co_2', 'co_3', 'co_4'],
        ),
      };

      await tester.pumpWidgetBuilder(
        _buildSlotScene(companies, occupancy),
        surfaceSize: const Size(400, 400),
      );
      await tester.pump();

      // Verify all 5 positions are distinct.
      final positions = [
        for (var i = 0; i < 5; i++)
          tester.getTopLeft(find.byKey(ValueKey('positioned_co_$i'))),
      ];

      for (var i = 0; i < positions.length; i++) {
        for (var j = i + 1; j < positions.length; j++) {
          expect(
            positions[i] == positions[j],
            isFalse,
            reason: 'Slot $i and slot $j must be at different positions',
          );
        }
      }

      // Verify slot 0 → centre, slot 4 → below (+0,+20).
      expect(positions[0].dx, closeTo(_cx - _kMarkerSize / 2, 1.0));
      expect(positions[0].dy, closeTo(_cy - _kMarkerSize / 2, 1.0));
      expect(positions[4].dy, closeTo(_cy + 20 - _kMarkerSize / 2, 1.0));

      await screenMatchesGolden(tester, 'map_node_offset_5_companies');
    });
  });
}
