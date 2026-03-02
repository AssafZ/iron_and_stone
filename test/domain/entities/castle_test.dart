import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  group('Castle', () {
    group('garrison initialisation', () {
      test('garrison is a flat Map<UnitRole, int> pool', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.player,
          garrison: {UnitRole.warrior: 20, UnitRole.archer: 10},
        );
        expect(castle.garrison, isA<Map<UnitRole, int>>());
        expect(castle.garrison[UnitRole.warrior], equals(20));
        expect(castle.garrison[UnitRole.archer], equals(10));
      });

      test('garrison starts empty by default (no units)', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.neutral,
          garrison: {},
        );
        expect(castle.garrison.isEmpty, isTrue);
      });

      test('garrison contains total counts by role, not Company slots', () {
        // Garrison holds raw unit counts — a Warrior count of 50 means
        // 50 warriors are available in the castle pool.
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.ai,
          garrison: {UnitRole.warrior: 50},
        );
        expect(castle.garrison[UnitRole.warrior], equals(50));
      });
    });

    group('ownership field', () {
      test('player ownership is set correctly', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.player,
          garrison: {},
        );
        expect(castle.ownership, equals(Ownership.player));
      });

      test('ai ownership is set correctly', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.ai,
          garrison: {},
        );
        expect(castle.ownership, equals(Ownership.ai));
      });

      test('neutral ownership is set correctly', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.neutral,
          garrison: {},
        );
        expect(castle.ownership, equals(Ownership.neutral));
      });
    });

    group('base cap', () {
      test('default cap is 250', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.neutral,
          garrison: {},
        );
        expect(castle.baseCap, equals(250));
      });
    });

    group('Peasant bonus calculation', () {
      test('growthRateMultiplier is 1.0 with no Peasants', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.player,
          garrison: {UnitRole.warrior: 10},
        );
        expect(castle.growthRateMultiplier, equals(1.0));
      });

      test('growthRateMultiplier is 1.05 with 1 Peasant (+5%)', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.player,
          garrison: {UnitRole.peasant: 1},
        );
        expect(castle.growthRateMultiplier, closeTo(1.05, 0.001));
      });

      test('growthRateMultiplier is 1.50 with 10 Peasants (+50%)', () {
        // 10 Peasants × 5% = +50% → 1.50
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.player,
          garrison: {UnitRole.peasant: 10},
        );
        expect(castle.growthRateMultiplier, closeTo(1.50, 0.001));
      });

      test('effectiveCap scales with Peasant bonus', () {
        // 10 Peasants → multiplier 1.5 → effective cap = 250 × 1.5 = 375
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.player,
          garrison: {UnitRole.peasant: 10},
        );
        expect(castle.effectiveCap, equals(375));
      });

      test('effectiveCap equals baseCap with no Peasants', () {
        final castle = Castle(
          id: 'c1',
          ownership: Ownership.player,
          garrison: {},
        );
        expect(castle.effectiveCap, equals(250));
      });
    });

    group('copyWith', () {
      test('copyWith updates ownership', () {
        final original = Castle(
          id: 'c1',
          ownership: Ownership.neutral,
          garrison: {},
        );
        final updated = original.copyWith(ownership: Ownership.player);
        expect(updated.ownership, equals(Ownership.player));
        expect(original.ownership, equals(Ownership.neutral));
      });

      test('copyWith updates garrison', () {
        final original = Castle(
          id: 'c1',
          ownership: Ownership.player,
          garrison: {UnitRole.warrior: 10},
        );
        final updated = original.copyWith(
          garrison: {UnitRole.warrior: 20},
        );
        expect(updated.garrison[UnitRole.warrior], equals(20));
        expect(original.garrison[UnitRole.warrior], equals(10));
      });
    });
  });
}
