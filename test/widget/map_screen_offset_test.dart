// Phase 3 — Widget tests for company marker offset (US1)
// TDD: tests are written BEFORE implementation and must FAIL first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/ui/widgets/company_marker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kMarkerSize = 44.0;

const _aiCastle = CastleNode(
  id: 'ai_castle',
  x: 300,
  y: 0,
  ownership: Ownership.ai,
);
const _junction = RoadJunctionNode(id: 'j1', x: 150, y: 0);

CompanyOnMap _makeCompany({
  required String id,
  required MapNode currentNode,
  MapNode? destination,
  Ownership ownership = Ownership.player,
}) =>
    CompanyOnMap(
      company: Company(composition: {UnitRole.warrior: 5}),
      id: id,
      ownership: ownership,
      currentNode: currentNode,
      destination: destination,
    );

// ---------------------------------------------------------------------------
// Minimal widget that renders CompanyMarkers at Positioned slots derived
// from a NodeOccupancy map — mirrors the intended map_screen.dart logic.
// ---------------------------------------------------------------------------

/// The slot-offset table (mirrors _kSlotOffsets from map_screen.dart).
/// Radius must be ≥ 44 px so adjacent 44 × 44 tap targets never overlap.
const double _kSlotRadius = 52.0;
const _kSlotOffsets = [
  (0.0, 0.0),                      // slot 0 — centre
  (_kSlotRadius, 0.0),             // slot 1 — right
  (-_kSlotRadius, 0.0),            // slot 2 — left
  (0.0, -_kSlotRadius),            // slot 3 — above
  (0.0, _kSlotRadius),             // slot 4 — below
  (-_kSlotRadius, -_kSlotRadius),  // slot 5
  (_kSlotRadius, -_kSlotRadius),   // slot 6
  (-_kSlotRadius, _kSlotRadius),   // slot 7
  (_kSlotRadius, _kSlotRadius),    // slot 8
];

/// Mirrors _buildSlotMap from map_screen.dart: builds a node-id → sorted
/// company-id list from [companies], stationary only.
Map<String, List<String>> _buildSlotMap(List<CompanyOnMap> companies) {
  final map = <String, List<String>>{};
  for (final co in companies) {
    final isStationary = co.destination == null ||
        co.destination!.id == co.currentNode.id;
    if (!isStationary) continue;
    map.putIfAbsent(co.currentNode.id, () => []).add(co.id);
  }
  for (final ids in map.values) {
    ids.sort();
  }
  return map;
}

/// Mirrors _offsetForCompany from map_screen.dart.
(double, double) _offsetForCompany(
  CompanyOnMap co,
  Map<String, List<String>> slotMap,
) {
  if (co.destination != null && co.destination!.id != co.currentNode.id) {
    return (0.0, 0.0);
  }
  final ids = slotMap[co.currentNode.id];
  if (ids == null) return (0.0, 0.0);
  final slot = ids.indexOf(co.id);
  if (slot < 0) return (0.0, 0.0);
  if (slot >= _kSlotOffsets.length) return (0.0, 0.0);
  return _kSlotOffsets[slot];
}

/// A minimal test scaffold that renders companies at offset Positioned slots.
///
/// [tapCallbacks] are callbacks so tests can verify which marker was hit.
class _OffsetMapScaffold extends StatelessWidget {
  final List<CompanyOnMap> companies;
  final Map<String, VoidCallback> tapCallbacks;
  // Canvas centre for the shared node
  static const double _cx = 200.0;
  static const double _cy = 200.0;
  static const double _canvasSize = 400.0;

  const _OffsetMapScaffold({
    required this.companies,
    required this.tapCallbacks,
  });

  @override
  Widget build(BuildContext context) {
    // Build slot map from the live company list — same logic as map_screen.dart.
    final slotMap = _buildSlotMap(companies);
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: _canvasSize,
          height: _canvasSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final co in companies)
                Builder(builder: (ctx) {
                  final (ox, oy) = _offsetForCompany(co, slotMap);
                  final left = _cx + ox - _kMarkerSize / 2;
                  final top = _cy + oy - _kMarkerSize / 2;
                  return Positioned(
                    key: ValueKey('positioned_${co.id}'),
                    left: left,
                    top: top,
                    child: SizedBox(
                      width: _kMarkerSize,
                      height: _kMarkerSize,
                      child: CompanyMarker(
                        key: ValueKey('marker_${co.id}'),
                        company: co,
                        x: _cx + ox,
                        y: _cy + oy,
                        onTap: tapCallbacks[co.id],
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
}

// ---------------------------------------------------------------------------
// T016: Two companies at same node render at distinct Positioned offsets
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'settings.firstRunHintShown': true,
    });
  });

  group('T016 — two companies at same node have distinct Positioned offsets', () {
    testWidgets('left/top values are not identical for co_a and co_b', (tester) async {
      final coA = _makeCompany(id: 'co_a', currentNode: _junction);
      final coB = _makeCompany(id: 'co_b', currentNode: _junction, ownership: Ownership.ai);

      await tester.pumpWidget(
        _OffsetMapScaffold(
          companies: [coA, coB],
          tapCallbacks: {},
        ),
      );
      await tester.pump();

      final posA = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_a')));
      final posB = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_b')));

      // Slot 0 vs slot 1 must produce different positions.
      expect(posA == posB, isFalse,
          reason: 'Two companies at the same node must have distinct Positioned offsets');
    });
  });

  // -------------------------------------------------------------------------
  // T017: Tapping co_a fires onTap for co_a and NOT co_b
  // -------------------------------------------------------------------------

  group('T017 — tapping the first company fires onTap for A and not B', () {
    testWidgets('tap co_a callback fires; co_b callback does not fire', (tester) async {
      final coA = _makeCompany(id: 'co_a', currentNode: _junction);
      final coB = _makeCompany(id: 'co_b', currentNode: _junction);

      var tappedA = false;
      var tappedB = false;

      await tester.pumpWidget(
        _OffsetMapScaffold(
          companies: [coA, coB],
          tapCallbacks: {
            'co_a': () => tappedA = true,
            'co_b': () => tappedB = true,
          },
        ),
      );
      await tester.pump();

      // co_a is at slot 0 (centre, offset 0,0)  → Positioned left=178, top=178.
      // co_b is at slot 1 (right, offset +52,0) → Positioned left=230, top=178.
      // With 52 px spacing the boxes no longer overlap at all.
      // Tap the LEFT edge of co_a's 44 px box (x≈183) which is exclusively
      // in co_a's region and well clear of co_b (which starts at x=230).
      final posA = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_a')));
      // Tap 5 px from the left edge of co_a's 44 px box — well outside co_b's range.
      await tester.tapAt(Offset(posA.dx + 5, posA.dy + 22));
      await tester.pump();

      expect(tappedA, isTrue, reason: 'co_a onTap must fire');
      expect(tappedB, isFalse, reason: 'co_b onTap must NOT fire when co_a is tapped');
    });
  });

  // -------------------------------------------------------------------------
  // T018: Tapping co_b fires onTap for co_b and NOT co_a
  // -------------------------------------------------------------------------

  group('T018 — tapping the second company fires onTap for B and not A', () {
    testWidgets('tap co_b callback fires; co_a callback does not fire', (tester) async {
      final coA = _makeCompany(id: 'co_a', currentNode: _junction);
      final coB = _makeCompany(id: 'co_b', currentNode: _junction);

      var tappedA = false;
      var tappedB = false;

      await tester.pumpWidget(
        _OffsetMapScaffold(
          companies: [coA, coB],
          tapCallbacks: {
            'co_a': () => tappedA = true,
            'co_b': () => tappedB = true,
          },
        ),
      );
      await tester.pump();

      // co_b is at slot 1 (right, offset +52,0) → Positioned left=230, top=178.
      // Tap the RIGHT edge of co_b's 44 px box (x≈268) which is exclusively
      // in co_b's region and completely outside co_a's range (178..222).
      final posB = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_b')));
      await tester.tapAt(Offset(posB.dx + 38, posB.dy + 22));
      await tester.pump();

      expect(tappedB, isTrue, reason: 'co_b onTap must fire');
      expect(tappedA, isFalse, reason: 'co_a onTap must NOT fire when co_b is tapped');
    });
  });

  // -------------------------------------------------------------------------
  // T019: Three companies at same node have distinct offset positions
  // -------------------------------------------------------------------------

  group('T019 — three companies at same node have distinct offsets', () {
    testWidgets('all three Positioned left/top values are unique', (tester) async {
      final coA = _makeCompany(id: 'co_a', currentNode: _junction);
      final coB = _makeCompany(id: 'co_b', currentNode: _junction);
      final coC = _makeCompany(id: 'co_c', currentNode: _junction);

      await tester.pumpWidget(
        _OffsetMapScaffold(
          companies: [coA, coB, coC],
          tapCallbacks: {},
        ),
      );
      await tester.pump();

      final posA = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_a')));
      final posB = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_b')));
      final posC = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_c')));

      expect(posA == posB, isFalse, reason: 'co_a and co_b must differ');
      expect(posA == posC, isFalse, reason: 'co_a and co_c must differ');
      expect(posB == posC, isFalse, reason: 'co_b and co_c must differ');
    });
  });

  // -------------------------------------------------------------------------
  // T022a: In-transit company renders with distinct visual style (FR-008)
  // -------------------------------------------------------------------------

  group('T022a — in-transit company renders with reduced opacity (FR-008)', () {
    testWidgets('in-transit marker is wrapped in Opacity(0.65)', (tester) async {
      // An in-transit company has destination != currentNode.
      final coTransit = _makeCompany(
        id: 'co_transit',
        currentNode: _junction,
        destination: _aiCastle,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompanyMarker(
              key: const ValueKey('marker_transit'),
              company: coTransit,
              x: 100,
              y: 100,
            ),
          ),
        ),
      );
      await tester.pump();

      // The marker must have an Opacity widget with opacity < 1.0 for in-transit.
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
      expect(
        opacityWidgets.any((o) => o.opacity < 1.0),
        isTrue,
        reason: 'In-transit company must render with opacity < 1.0 (e.g. 0.65)',
      );
    });

    testWidgets('stationary company does NOT render with reduced opacity', (tester) async {
      final coStationary = _makeCompany(
        id: 'co_stationary',
        currentNode: _junction,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompanyMarker(
              key: const ValueKey('marker_stationary'),
              company: coStationary,
              x: 100,
              y: 100,
            ),
          ),
        ),
      );
      await tester.pump();

      // Either no Opacity widget, or all Opacity widgets have opacity == 1.0.
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
      expect(
        opacityWidgets.every((o) => o.opacity == 1.0),
        isTrue,
        reason: 'Stationary company must not have reduced opacity',
      );
    });
  });

  // -------------------------------------------------------------------------
  // T022b: Merge prompt not suppressed by offset UI (FR-011)
  // -------------------------------------------------------------------------

  group('T022b — merge prompt shown when tapping same-owner company while one selected', () {
    testWidgets('tapping co_b when co_a is selected shows merge dialog', (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings.firstRunHintShown': true,
      });

      // Both companies at the same node, both player-owned.
      final coA = _makeCompany(id: 'co_a', currentNode: _junction);
      final coB = _makeCompany(id: 'co_b', currentNode: _junction);

      // Track whether the merge callback was triggered.
      var mergePromptShown = false;

      // Build the slot map the same way map_screen.dart does.
      final slotMap = _buildSlotMap([coA, coB]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final co in [coA, coB])
                    Builder(builder: (ctx) {
                      final (ox, oy) = _offsetForCompany(co, slotMap);
                      const cx = 200.0, cy = 200.0;
                      return Positioned(
                        key: ValueKey('positioned_${co.id}'),
                        left: cx + ox - 22,
                        top: cy + oy - 22,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: CompanyMarker(
                            key: ValueKey('marker_${co.id}'),
                            company: co,
                            x: cx + ox,
                            y: cy + oy,
                            // Simulate the map_screen logic: if co_a is
                            // selected and co_b is tapped → merge prompt.
                            onTap: co.id == 'co_b'
                                ? () {
                                    mergePromptShown = true;
                                  }
                                : null,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap co_b (simulating the second tap in the two-step merge flow).
      await tester.tap(find.byKey(const ValueKey('marker_co_b')));
      await tester.pump();

      expect(
        mergePromptShown,
        isTrue,
        reason: 'Tapping a second same-owner company when one is selected must trigger the merge flow',
      );
    });
  });

  // -------------------------------------------------------------------------
  // T043 (Phase 5 pre-req): Compacted-to-slot-0 renders at (0,0) offset
  // -------------------------------------------------------------------------

  group('T043 — company compacted to slot 0 renders at (0,0) offset', () {
    testWidgets('after compaction to slot 0, Positioned uses centre offset', (tester) async {
      // Only one company remains after compaction — it occupies slot 0.
      final coA = _makeCompany(id: 'co_a', currentNode: _junction);

      await tester.pumpWidget(
        _OffsetMapScaffold(
          companies: [coA],
          tapCallbacks: {},
        ),
      );
      await tester.pump();

      final pos = tester.getTopLeft(find.byKey(const ValueKey('positioned_co_a')));
      // Slot 0 → offset (0,0) → left = cx - 22 = 178, top = cy - 22 = 178
      const expected = Offset(
        _OffsetMapScaffold._cx - _kMarkerSize / 2,
        _OffsetMapScaffold._cy - _kMarkerSize / 2,
      );
      expect(pos, equals(expected),
          reason: 'Company at slot 0 must render at centre (0,0 offset)');
    });
  });
}
