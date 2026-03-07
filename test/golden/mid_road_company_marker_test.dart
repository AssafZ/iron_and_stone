// T041 [Phase 9]: Golden test — mid-road company marker visual regression (SC-007).
//
// Renders two CompanyMarker widgets at interpolated mid-road positions on a
// horizontal segment. The golden captures exact pixel layout and colours so
// future refactors cannot accidentally break the visual rendering.
//
// Run with --update-goldens after a deliberate visual change.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';
import 'package:iron_and_stone/ui/widgets/company_marker.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const _kCanvasWidth = 400.0;
const _kCanvasHeight = 200.0;
const _kSegmentY = 100.0;  // y coordinate of the horizontal segment
const _kSegmentX0 = 50.0;  // left node x
const _kSegmentX1 = 350.0; // right node x
const _kSegmentLength = _kSegmentX1 - _kSegmentX0; // 300 px

const _leftNode = RoadJunctionNode(id: 'left', x: 0, y: 0);
// _rightNode is used only as a map reference — referenced in RoadPosition strings.

/// Build a [CompanyOnMap] that is stopped mid-road at [progress] on the
/// left→right segment.
CompanyOnMap _midRoadCompany({
  required String id,
  required Ownership ownership,
  required double progress,
}) =>
    CompanyOnMap(
      id: id,
      ownership: ownership,
      currentNode: _leftNode,
      progress: progress,
      midRoadDestination: RoadPosition(
        currentNodeId: 'left',
        nextNodeId: 'right',
        progress: progress,
      ),
      company: Company(composition: {UnitRole.warrior: 10}),
    );

/// Compute the canvas-space x for a company at [progress] on the segment.
double _cx(double progress) => _kSegmentX0 + _kSegmentLength * progress;

/// Build the scene widget: a fixed-size canvas with a horizontal road line
/// and two [CompanyMarker] widgets placed at their fractional positions.
Widget _buildScene(List<CompanyOnMap> companies) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFFF5E6C8),
      body: SizedBox(
        width: _kCanvasWidth,
        height: _kCanvasHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Road segment line
            Positioned(
              left: _kSegmentX0,
              top: _kSegmentY - 1,
              child: Container(
                width: _kSegmentLength,
                height: 2,
                color: const Color(0xFF8B6914),
              ),
            ),
            // Left node dot
            Positioned(
              left: _kSegmentX0 - 6,
              top: _kSegmentY - 6,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF555555),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Right node dot
            Positioned(
              left: _kSegmentX1 - 6,
              top: _kSegmentY - 6,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF555555),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Company markers at fractional positions
            for (final co in companies)
              Positioned(
                key: ValueKey('positioned_${co.id}'),
                left: _cx(co.progress) - 22,
                top: _kSegmentY - 22,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CompanyMarker(
                    key: ValueKey('company_marker_${co.id}'),
                    company: co,
                    x: _cx(co.progress),
                    y: _kSegmentY,
                    isSelected: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// T041 Tests
// ---------------------------------------------------------------------------

void main() {
  group('T041 [Phase 9]: mid-road company marker golden', () {
    setUpAll(() async {
      await loadAppFonts();
    });

    testGoldens(
      'two mid-road markers at progress=0.25 (player) and progress=0.60 (AI)',
      (tester) async {
        final player = _midRoadCompany(
          id: 'player_mid',
          ownership: Ownership.player,
          progress: 0.25,
        );
        final ai = _midRoadCompany(
          id: 'ai_mid',
          ownership: Ownership.ai,
          progress: 0.60,
        );

        await tester.pumpWidgetBuilder(
          _buildScene([player, ai]),
          surfaceSize: const Size(_kCanvasWidth, _kCanvasHeight),
        );

        // Both markers must be present.
        expect(
          find.byKey(const ValueKey('company_marker_player_mid')),
          findsOneWidget,
          reason: 'Player mid-road marker must be rendered',
        );
        expect(
          find.byKey(const ValueKey('company_marker_ai_mid')),
          findsOneWidget,
          reason: 'AI mid-road marker must be rendered',
        );

        await screenMatchesGolden(tester, 'mid_road_company_markers');
      },
    );

    testGoldens(
      'single selected mid-road marker at progress=0.50 has gold selection ring',
      (tester) async {
        final selected = CompanyOnMap(
          id: 'selected_mid',
          ownership: Ownership.player,
          currentNode: _leftNode,
          progress: 0.50,
          midRoadDestination: RoadPosition(
            currentNodeId: 'left',
            nextNodeId: 'right',
            progress: 0.50,
          ),
          company: Company(composition: {UnitRole.warrior: 5}),
        );

        await tester.pumpWidgetBuilder(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFFF5E6C8),
              body: SizedBox(
                width: _kCanvasWidth,
                height: _kCanvasHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: _cx(0.50) - 22,
                      top: _kSegmentY - 22,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: CompanyMarker(
                          key: const ValueKey('company_marker_selected_mid'),
                          company: selected,
                          x: _cx(0.50),
                          y: _kSegmentY,
                          isSelected: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          surfaceSize: const Size(_kCanvasWidth, _kCanvasHeight),
        );

        expect(
          find.byKey(const ValueKey('company_marker_selected_mid')),
          findsOneWidget,
        );

        await screenMatchesGolden(tester, 'mid_road_selected_marker');
      },
    );
  });
}
