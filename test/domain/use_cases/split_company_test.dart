import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/split_company.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  const node = RoadJunctionNode(id: 'j1', x: 0, y: 0);

  CompanyOnMap makeCompany({
    required String id,
    required Map<UnitRole, int> composition,
    Ownership ownership = Ownership.player,
  }) {
    return CompanyOnMap(
      id: id,
      company: Company(composition: composition),
      ownership: ownership,
      currentNode: node,
    );
  }

  group('SplitCompany — output counts sum to original', () {
    test('split produces kept + splitOff summing to original total', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 20, UnitRole.archer: 10},
      );
      final toSplit = {UnitRole.archer: 10};

      final result = const SplitCompany().split(
        company: original,
        splitComposition: toSplit,
        keptId: 'co1',
        splitId: 'co2',
      );

      expect(
        result.kept.company.totalSoldiers.value +
            result.splitOff.company.totalSoldiers.value,
        original.company.totalSoldiers.value,
      );
    });

    test('splitOff Company has exactly the composition requested', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 15, UnitRole.knight: 10},
      );
      final toSplit = {UnitRole.warrior: 5};

      final result = const SplitCompany().split(
        company: original,
        splitComposition: toSplit,
        keptId: 'co1',
        splitId: 'co2',
      );

      expect(result.splitOff.company.composition[UnitRole.warrior], 5);
      expect(result.kept.company.composition[UnitRole.warrior], 10);
      expect(result.kept.company.composition[UnitRole.knight], 10);
    });

    test('new (splitOff) Company is placed on the same node as original', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 20},
      );

      final result = const SplitCompany().split(
        company: original,
        splitComposition: {UnitRole.warrior: 10},
        keptId: 'co1',
        splitId: 'co2',
      );

      expect(result.splitOff.currentNode.id, original.currentNode.id);
    });

    test('kept Company is placed on the same node as original', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 20},
      );

      final result = const SplitCompany().split(
        company: original,
        splitComposition: {UnitRole.warrior: 10},
        keptId: 'co1',
        splitId: 'co2',
      );

      expect(result.kept.currentNode.id, original.currentNode.id);
    });

    test('splitOff inherits ownership from original', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 20},
        ownership: Ownership.player,
      );

      final result = const SplitCompany().split(
        company: original,
        splitComposition: {UnitRole.warrior: 10},
        keptId: 'co1',
        splitId: 'co2',
      );

      expect(result.splitOff.ownership, Ownership.player);
    });

    test('splitting all soldiers produces empty kept Company', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 10},
      );

      final result = const SplitCompany().split(
        company: original,
        splitComposition: {UnitRole.warrior: 10},
        keptId: 'co1',
        splitId: 'co2',
      );

      expect(result.kept.company.totalSoldiers.value, 0);
      expect(result.splitOff.company.totalSoldiers.value, 10);
    });
  });

  group('SplitCompany — role selection validated against available composition', () {
    test('requesting a role not in original throws SplitCompanyException', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 10},
      );

      expect(
        () => const SplitCompany().split(
          company: original,
          splitComposition: {UnitRole.archer: 5},
          keptId: 'co1',
          splitId: 'co2',
        ),
        throwsA(isA<SplitCompanyException>()),
      );
    });

    test('requesting more of a role than available throws SplitCompanyException', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 5},
      );

      expect(
        () => const SplitCompany().split(
          company: original,
          splitComposition: {UnitRole.warrior: 10},
          keptId: 'co1',
          splitId: 'co2',
        ),
        throwsA(isA<SplitCompanyException>()),
      );
    });

    test('zero-count role in splitComposition throws SplitCompanyException', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 10},
      );

      expect(
        () => const SplitCompany().split(
          company: original,
          splitComposition: {UnitRole.warrior: 0},
          keptId: 'co1',
          splitId: 'co2',
        ),
        throwsA(isA<SplitCompanyException>()),
      );
    });

    test('empty splitComposition throws SplitCompanyException', () {
      final original = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 10},
      );

      expect(
        () => const SplitCompany().split(
          company: original,
          splitComposition: {},
          keptId: 'co1',
          splitId: 'co2',
        ),
        throwsA(isA<SplitCompanyException>()),
      );
    });
  });
}
