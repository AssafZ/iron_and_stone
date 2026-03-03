import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/merge_split_rules.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Merge tests
  // ---------------------------------------------------------------------------

  group('MergeSplitRules.merge — total ≤ 50', () {
    test('merging two Companies whose combined count is exactly 50 yields one Company of 50', () {
      final a = Company(composition: {UnitRole.warrior: 25});
      final b = Company(composition: {UnitRole.warrior: 25});

      final result = MergeSplitRules.merge(a, b);

      expect(result.primary.totalSoldiers.value, 50);
      expect(result.overflow, isNull);
      expect(result.primary.composition[UnitRole.warrior], 50);
    });

    test('merging two Companies with different roles combines role counts', () {
      final a = Company(composition: {UnitRole.warrior: 10, UnitRole.archer: 5});
      final b = Company(composition: {UnitRole.knight: 8, UnitRole.catapult: 3});

      final result = MergeSplitRules.merge(a, b);

      expect(result.overflow, isNull);
      expect(result.primary.totalSoldiers.value, 26);
      expect(result.primary.composition[UnitRole.warrior], 10);
      expect(result.primary.composition[UnitRole.archer], 5);
      expect(result.primary.composition[UnitRole.knight], 8);
      expect(result.primary.composition[UnitRole.catapult], 3);
    });

    test('merging two empty Companies yields an empty Company', () {
      final a = Company(composition: {});
      final b = Company(composition: {});

      final result = MergeSplitRules.merge(a, b);

      expect(result.primary.totalSoldiers.value, 0);
      expect(result.overflow, isNull);
    });
  });

  group('MergeSplitRules.merge — total > 50 (overflow)', () {
    test('merging two Companies whose combined count is 60 yields primary=50 + overflow=10', () {
      final a = Company(composition: {UnitRole.warrior: 30});
      final b = Company(composition: {UnitRole.warrior: 30});

      final result = MergeSplitRules.merge(a, b);

      expect(result.primary.totalSoldiers.value, 50);
      expect(result.overflow, isNotNull);
      expect(result.overflow!.totalSoldiers.value, 10);
      expect(
        result.primary.totalSoldiers.value + result.overflow!.totalSoldiers.value,
        60,
      );
    });

    test('overflow Company has the same roles as the remainder', () {
      // 40 Knights + 20 Archers = 60 total; primary gets 50, overflow gets 10
      final a = Company(composition: {UnitRole.knight: 40});
      final b = Company(composition: {UnitRole.archer: 20});

      final result = MergeSplitRules.merge(a, b);

      expect(result.primary.totalSoldiers.value, 50);
      expect(result.overflow!.totalSoldiers.value, 10);
      // Combined role counts across primary + overflow must equal original totals
      final combinedKnight =
          (result.primary.composition[UnitRole.knight] ?? 0) +
          (result.overflow!.composition[UnitRole.knight] ?? 0);
      final combinedArcher =
          (result.primary.composition[UnitRole.archer] ?? 0) +
          (result.overflow!.composition[UnitRole.archer] ?? 0);
      expect(combinedKnight, 40);
      expect(combinedArcher, 20);
    });

    test('no soldiers are lost: primary.total + overflow.total == combined total', () {
      final a = Company(composition: {UnitRole.peasant: 25, UnitRole.warrior: 25});
      final b = Company(composition: {UnitRole.archer: 10, UnitRole.catapult: 5});

      final result = MergeSplitRules.merge(a, b);

      final total = result.primary.totalSoldiers.value +
          (result.overflow?.totalSoldiers.value ?? 0);
      expect(total, 65);
    });
  });

  // ---------------------------------------------------------------------------
  // Split tests
  // ---------------------------------------------------------------------------

  group('MergeSplitRules.split — happy paths', () {
    test('split produces two Companies that sum to original', () {
      final original = Company(
        composition: {UnitRole.warrior: 20, UnitRole.archer: 10},
      );
      final toSplit = {UnitRole.archer: 10};

      final result = MergeSplitRules.split(original, toSplit);

      expect(result.kept.totalSoldiers.value + result.splitOff.totalSoldiers.value,
          original.totalSoldiers.value);
      expect(result.splitOff.composition[UnitRole.archer], 10);
      expect(result.kept.composition[UnitRole.archer] ?? 0, 0);
      expect(result.kept.composition[UnitRole.warrior], 20);
    });

    test('split by partial role count preserves remainder in kept Company', () {
      final original = Company(
        composition: {UnitRole.warrior: 10, UnitRole.knight: 8},
      );
      final toSplit = {UnitRole.warrior: 4};

      final result = MergeSplitRules.split(original, toSplit);

      expect(result.splitOff.composition[UnitRole.warrior], 4);
      expect(result.kept.composition[UnitRole.warrior], 6);
      expect(result.kept.composition[UnitRole.knight], 8);
    });

    test('split every soldier produces empty kept Company', () {
      final original = Company(composition: {UnitRole.warrior: 10});
      final toSplit = {UnitRole.warrior: 10};

      final result = MergeSplitRules.split(original, toSplit);

      expect(result.kept.totalSoldiers.value, 0);
      expect(result.splitOff.totalSoldiers.value, 10);
    });
  });

  group('MergeSplitRules.split — validation', () {
    test('split with zero-count role throws ArgumentError', () {
      final original = Company(composition: {UnitRole.warrior: 20});
      final toSplit = {UnitRole.warrior: 0};

      expect(
        () => MergeSplitRules.split(original, toSplit),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('split requesting more than available for a role throws ArgumentError', () {
      final original = Company(composition: {UnitRole.warrior: 5});
      final toSplit = {UnitRole.warrior: 10};

      expect(
        () => MergeSplitRules.split(original, toSplit),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('split requesting a role not in original Company throws ArgumentError', () {
      final original = Company(composition: {UnitRole.warrior: 5});
      final toSplit = {UnitRole.archer: 2};

      expect(
        () => MergeSplitRules.split(original, toSplit),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('split with empty toSplit map throws ArgumentError', () {
      final original = Company(composition: {UnitRole.warrior: 10});

      expect(
        () => MergeSplitRules.split(original, {}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
