// T062 — Failing unit tests for TickCastleGrowth use case
// Red-Green-Refactor: these tests must FAIL before implementation exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/tick_castle_growth.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

Castle _castle({required Map<UnitRole, int> garrison, String id = 'c1'}) =>
    Castle(id: id, ownership: Ownership.player, garrison: garrison);

void main() {
  group('TickCastleGrowth', () {
    const useCase = TickCastleGrowth();

    // -------------------------------------------------------------------------
    // Single tick behaviour
    // -------------------------------------------------------------------------

    test('single tick increases garrison count for a role below cap', () {
      final castle = _castle(garrison: {UnitRole.warrior: 5});
      final result = useCase.tick(castle);
      expect(result.garrison[UnitRole.warrior], greaterThan(5));
    });

    test('returns a Castle, not null', () {
      final castle = _castle(garrison: {UnitRole.warrior: 0});
      final result = useCase.tick(castle);
      expect(result, isA<Castle>());
    });

    test('castle id and ownership are preserved after tick', () {
      final castle = _castle(garrison: {UnitRole.warrior: 5});
      final result = useCase.tick(castle);
      expect(result.id, equals(castle.id));
      expect(result.ownership, equals(castle.ownership));
    });

    // -------------------------------------------------------------------------
    // Cap enforcement at role level (50)
    // -------------------------------------------------------------------------

    test('role at 50 does not grow beyond 50', () {
      final castle = _castle(garrison: {UnitRole.warrior: 50, UnitRole.archer: 2});
      final result = useCase.tick(castle);
      expect(result.garrison[UnitRole.warrior], equals(50));
    });

    // -------------------------------------------------------------------------
    // Castle Cap enforcement (250)
    // -------------------------------------------------------------------------

    test('garrison at castle cap halts all growth', () {
      final garrison = {
        UnitRole.warrior: 50,
        UnitRole.archer: 50,
        UnitRole.knight: 50,
        UnitRole.catapult: 50,
        UnitRole.peasant: 50,
      };
      final castle = _castle(garrison: garrison);
      final result = useCase.tick(castle);
      final totalAfter = result.garrison.values.fold(0, (s, v) => s + v);
      expect(totalAfter, equals(250));
    });

    // -------------------------------------------------------------------------
    // Peasant bonus
    // -------------------------------------------------------------------------

    test('Peasant bonus computed before cap check (10 Peasants = 1.5× multiplier)', () {
      // Castle with 10 peasants has effectiveCap = 250 * 1.5 = 375.
      // Garrison starts at 0 warriors, so well below cap — growth must occur.
      final castle = _castle(garrison: {
        UnitRole.peasant: 10,
        UnitRole.warrior: 0,
      });
      final result = useCase.tick(castle);
      expect(result.garrison[UnitRole.warrior], greaterThanOrEqualTo(1));
    });
  });
}
