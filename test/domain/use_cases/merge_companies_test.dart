import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/merge_companies.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  // Helper: build a CompanyOnMap on a given node.
  CompanyOnMap makeCompany({
    required String id,
    required Map<UnitRole, int> composition,
    required MapNode node,
    Ownership ownership = Ownership.player,
  }) {
    return CompanyOnMap(
      id: id,
      company: Company(composition: composition),
      ownership: ownership,
      currentNode: node,
    );
  }

  const sharedNode = RoadJunctionNode(id: 'j1', x: 0, y: 0);
  const differentNode = RoadJunctionNode(id: 'j2', x: 10, y: 10);

  group('MergeCompanies — happy path ≤ 50', () {
    test('merging two Companies on same node with combined ≤ 50 produces one Company', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 20},
        node: sharedNode,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.warrior: 20},
        node: sharedNode,
      );

      final result = const MergeCompanies().merge(companyA: a, companyB: b, newId: 'co3');

      expect(result.primary.company.totalSoldiers.value, 40);
      expect(result.overflow, isNull);
      expect(result.primary.currentNode, sharedNode);
    });

    test('merged Company is placed on the same node as the input Companies', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.knight: 10},
        node: sharedNode,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.archer: 5},
        node: sharedNode,
      );

      final result = const MergeCompanies().merge(companyA: a, companyB: b, newId: 'co3');

      expect(result.primary.currentNode.id, 'j1');
    });

    test('merged Company inherits ownership of input Companies', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 5},
        node: sharedNode,
        ownership: Ownership.player,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.warrior: 5},
        node: sharedNode,
        ownership: Ownership.player,
      );

      final result = const MergeCompanies().merge(companyA: a, companyB: b, newId: 'co3');

      expect(result.primary.ownership, Ownership.player);
    });
  });

  group('MergeCompanies — overflow (combined > 50, SC-005)', () {
    test('merging two Companies with combined total 70 yields primary=50 + overflow=20', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 40},
        node: sharedNode,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.warrior: 30},
        node: sharedNode,
      );

      final result = const MergeCompanies().merge(
        companyA: a,
        companyB: b,
        newId: 'co3',
        overflowId: 'co4',
      );

      expect(result.primary.company.totalSoldiers.value, 50);
      expect(result.overflow, isNotNull);
      expect(result.overflow!.company.totalSoldiers.value, 20);
    });

    test('overflow Company is placed on the same node as the primary', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 40},
        node: sharedNode,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.warrior: 30},
        node: sharedNode,
      );

      final result = const MergeCompanies().merge(
        companyA: a,
        companyB: b,
        newId: 'co3',
        overflowId: 'co4',
      );

      expect(result.overflow!.currentNode.id, sharedNode.id);
    });

    test('no soldiers are lost when overflow occurs', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 50},
        node: sharedNode,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.warrior: 50},
        node: sharedNode,
      );

      final result = const MergeCompanies().merge(
        companyA: a,
        companyB: b,
        newId: 'co3',
        overflowId: 'co4',
      );

      final total = result.primary.company.totalSoldiers.value +
          (result.overflow?.company.totalSoldiers.value ?? 0);
      expect(total, 100);
    });
  });

  group('MergeCompanies — validation', () {
    test('merging Companies on different nodes throws MergeCompaniesException', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 10},
        node: sharedNode,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.warrior: 10},
        node: differentNode,
      );

      expect(
        () => const MergeCompanies().merge(companyA: a, companyB: b, newId: 'co3'),
        throwsA(isA<MergeCompaniesException>()),
      );
    });

    test('merging Companies with different ownerships throws MergeCompaniesException', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 10},
        node: sharedNode,
        ownership: Ownership.player,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.warrior: 10},
        node: sharedNode,
        ownership: Ownership.ai,
      );

      expect(
        () => const MergeCompanies().merge(companyA: a, companyB: b, newId: 'co3'),
        throwsA(isA<MergeCompaniesException>()),
      );
    });

    test('merging where overflow would occur but no overflowId provided throws', () {
      final a = makeCompany(
        id: 'co1',
        composition: {UnitRole.warrior: 40},
        node: sharedNode,
      );
      final b = makeCompany(
        id: 'co2',
        composition: {UnitRole.warrior: 40},
        node: sharedNode,
      );

      expect(
        () => const MergeCompanies().merge(companyA: a, companyB: b, newId: 'co3'),
        throwsA(isA<MergeCompaniesException>()),
      );
    });
  });
}
