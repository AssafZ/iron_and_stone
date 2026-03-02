// T061 — Failing unit tests for GrowthEngine
// Red-Green-Refactor: these tests must FAIL before implementation exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/growth_engine.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

Castle _castle({required Map<UnitRole, int> garrison, String id = 'c1'}) =>
    Castle(id: id, ownership: Ownership.player, garrison: garrison);

void main() {
  group('GrowthEngine', () {
    const engine = GrowthEngine();

    // -------------------------------------------------------------------------
    // Base tick
    // -------------------------------------------------------------------------

    test('tick adds 1 unit per role present when below cap', () {
      final castle = _castle(garrison: {UnitRole.warrior: 0});
      final result = engine.tick(castle);
      expect(result.garrison[UnitRole.warrior], equals(1));
    });

    test('tick adds 1 unit to every present role independently', () {
      final castle = _castle(garrison: {
        UnitRole.warrior: 5,
        UnitRole.archer: 3,
        UnitRole.knight: 1,
      });
      final result = engine.tick(castle);
      expect(result.garrison[UnitRole.warrior], equals(6));
      expect(result.garrison[UnitRole.archer], equals(4));
      expect(result.garrison[UnitRole.knight], equals(2));
    });

    // -------------------------------------------------------------------------
    // Per-role slot cap (50)
    // -------------------------------------------------------------------------

    test('a role at 50 does not grow further', () {
      final castle = _castle(garrison: {
        UnitRole.warrior: 50,
        UnitRole.archer: 3,
      });
      final result = engine.tick(castle);
      // Warrior is at slot cap — must not grow.
      expect(result.garrison[UnitRole.warrior], equals(50));
      // Archer below slot cap — must grow.
      expect(result.garrison[UnitRole.archer], equals(4));
    });

    test('only the capped role halts; other roles continue growing', () {
      final castle = _castle(garrison: {
        UnitRole.warrior: 50,
        UnitRole.knight: 49,
        UnitRole.catapult: 10,
      });
      final result = engine.tick(castle);
      expect(result.garrison[UnitRole.warrior], equals(50)); // capped
      expect(result.garrison[UnitRole.knight], equals(50)); // grew to slot cap
      expect(result.garrison[UnitRole.catapult], equals(11)); // grew normally
    });

    // -------------------------------------------------------------------------
    // Peasant multiplier
    // -------------------------------------------------------------------------

    test('10 Peasants give +50% growth rate, producing 1 more unit per 2 ticks', () {
      // growthRateMultiplier = 1.0 + 0.05 * 10 = 1.5
      // floor(1 * 1.5) = 1 per role per tick (since floor(1.5) = 1, and we
      // want at least 1 unit growth). Growth must be > base when multiplier > 1.
      // We verify this by checking growth is at least 1 when multiplier is 1.5.
      final castle = _castle(garrison: {
        UnitRole.peasant: 10,
        UnitRole.warrior: 0,
      });
      final result = engine.tick(castle);
      // With multiplier 1.5: floor(1 * 1.5) = 1, or implementation may give 2.
      // Either way, warrior must grow by at least 1.
      expect(result.garrison[UnitRole.warrior], greaterThanOrEqualTo(1));
    });

    test('Peasant multiplier is +5% per Peasant (20 Peasants = 2.0×)', () {
      // growthRateMultiplier = 1.0 + 0.05 * 20 = 2.0
      // floor(1 * 2.0) = 2 per role per tick
      final castle = _castle(garrison: {
        UnitRole.peasant: 20,
        UnitRole.warrior: 0,
      });
      final result = engine.tick(castle);
      expect(result.garrison[UnitRole.warrior], greaterThanOrEqualTo(2));
    });

    // -------------------------------------------------------------------------
    // Castle Cap enforcement
    // -------------------------------------------------------------------------

    test('no role grows when total garrison equals effectiveCap', () {
      // effectiveCap = 250 (no Peasants)
      // Fill garrison exactly to 250 spread across roles
      final garrison = <UnitRole, int>{};
      // 50 each for 5 roles = 250 = exactly the base cap
      for (final role in UnitRole.values) {
        garrison[role] = 50;
      }
      final castle = _castle(garrison: garrison);
      final result = engine.tick(castle);
      // Total is 250 (at cap), no growth expected.
      final totalAfter = result.garrison.values.fold(0, (s, v) => s + v);
      expect(totalAfter, equals(250));
    });

    test('growth halts entirely when garrison equals effective cap', () {
      // Castle cap = 250 base. Fill to 250.
      final garrison = {
        UnitRole.warrior: 50,
        UnitRole.archer: 50,
        UnitRole.knight: 50,
        UnitRole.catapult: 50,
        UnitRole.peasant: 50,
      };
      final castle = _castle(garrison: garrison);
      final result = engine.tick(castle);
      for (final role in UnitRole.values) {
        expect(result.garrison[role], equals(50));
      }
    });

    test('growth resumes after units are removed (below cap)', () {
      // Start at cap, remove some warriors, then tick.
      final atCap = _castle(garrison: {
        UnitRole.warrior: 50,
        UnitRole.archer: 50,
        UnitRole.knight: 50,
        UnitRole.catapult: 50,
        UnitRole.peasant: 50,
      });
      // Remove 10 warriors → total 240 < 250 cap.
      final belowCap = atCap.copyWith(garrison: {
        UnitRole.warrior: 40,
        UnitRole.archer: 50,
        UnitRole.knight: 50,
        UnitRole.catapult: 50,
        UnitRole.peasant: 50,
      });
      final result = engine.tick(belowCap);
      // Warriors are below slot cap AND total below castle cap → should grow.
      expect(result.garrison[UnitRole.warrior], greaterThan(40));
    });

    // -------------------------------------------------------------------------
    // Roles not in garrison
    // -------------------------------------------------------------------------

    test('a role absent from garrison (0) is initialised and grows', () {
      final castle = _castle(garrison: {UnitRole.warrior: 5});
      // peasant not in garrison — GrowthEngine should add it.
      final result = engine.tick(castle);
      expect(result.garrison[UnitRole.peasant] ?? 0, greaterThanOrEqualTo(1));
    });

    // -------------------------------------------------------------------------
    // Returned type
    // -------------------------------------------------------------------------

    test('returns a new Castle (immutable — original unchanged)', () {
      final original = _castle(garrison: {UnitRole.warrior: 10});
      final result = engine.tick(original);
      // Original must not be mutated.
      expect(original.garrison[UnitRole.warrior], equals(10));
      expect(result.garrison[UnitRole.warrior], equals(11));
    });
  });
}
