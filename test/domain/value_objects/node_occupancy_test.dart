import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/node_occupancy.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _nodeA = RoadJunctionNode(id: 'nodeA', x: 0, y: 0);
const _nodeB = RoadJunctionNode(id: 'nodeB', x: 100, y: 0);

CompanyOnMap _makeCompany({
  required String id,
  required MapNode currentNode,
  MapNode? destination,
  Ownership ownership = Ownership.player,
}) {
  return CompanyOnMap(
    company: Company(composition: {UnitRole.warrior: 5}),
    id: id,
    ownership: ownership,
    currentNode: currentNode,
    destination: destination,
  );
}

// ---------------------------------------------------------------------------
// T004: Construction with nodeId and empty orderedIds
// ---------------------------------------------------------------------------

void main() {
  group('NodeOccupancy — construction (T004)', () {
    test('constructs with nodeId and empty orderedIds', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: []);
      expect(occ.nodeId, 'nodeA');
      expect(occ.orderedIds, isEmpty);
    });

    test('constructs with nodeId and non-empty orderedIds', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2']);
      expect(occ.nodeId, 'nodeA');
      expect(occ.orderedIds, ['co1', 'co2']);
    });

    test('orderedIds is a defensive copy — external mutation does not affect value object', () {
      final ids = ['co1', 'co2'];
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ids);
      ids.add('co3');
      expect(occ.orderedIds, ['co1', 'co2']);
    });
  });

  // -------------------------------------------------------------------------
  // T005: withArrival — appends id and is idempotent
  // -------------------------------------------------------------------------

  group('NodeOccupancy — withArrival (T005)', () {
    test('appends a new id at the end', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1']);
      final updated = occ.withArrival('co2');
      expect(updated.orderedIds, ['co1', 'co2']);
    });

    test('first arrival produces single-element list', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: []);
      final updated = occ.withArrival('co1');
      expect(updated.orderedIds, ['co1']);
    });

    test('is idempotent — no-op if id already present', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2']);
      final updated = occ.withArrival('co1');
      expect(updated.orderedIds, ['co1', 'co2']);
    });

    test('idempotent — no-op if id present at any position', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      final updated = occ.withArrival('co2');
      expect(updated.orderedIds, ['co1', 'co2', 'co3']);
    });

    test('returns a new instance (immutability)', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1']);
      final updated = occ.withArrival('co2');
      expect(identical(occ, updated), isFalse);
      expect(occ.orderedIds, ['co1']); // original unchanged
    });

    test('nodeId is preserved after withArrival', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: []);
      final updated = occ.withArrival('co1');
      expect(updated.nodeId, 'nodeA');
    });
  });

  // -------------------------------------------------------------------------
  // T006: withDeparture — removes id, compacts, preserves order
  // -------------------------------------------------------------------------

  group('NodeOccupancy — withDeparture (T006)', () {
    test('removes the specified id', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      final updated = occ.withDeparture('co2');
      expect(updated.orderedIds, ['co1', 'co3']);
    });

    test('compacts — no gaps after removal', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3', 'co4']);
      final updated = occ.withDeparture('co1');
      expect(updated.orderedIds, ['co2', 'co3', 'co4']);
    });

    test('preserves relative arrival order after removal', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      final updated = occ.withDeparture('co1');
      expect(updated.orderedIds, ['co2', 'co3']);
      expect(updated.orderedIds.indexOf('co2'), 0);
      expect(updated.orderedIds.indexOf('co3'), 1);
    });

    test('removing last element results in empty list', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1']);
      final updated = occ.withDeparture('co1');
      expect(updated.orderedIds, isEmpty);
    });

    test('no-op if id not present', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2']);
      final updated = occ.withDeparture('co99');
      expect(updated.orderedIds, ['co1', 'co2']);
    });

    test('returns a new instance (immutability)', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2']);
      final updated = occ.withDeparture('co1');
      expect(identical(occ, updated), isFalse);
      expect(occ.orderedIds, ['co1', 'co2']); // original unchanged
    });
  });

  // -------------------------------------------------------------------------
  // T007: slotIndex — correct 0-based index or null if absent
  // -------------------------------------------------------------------------

  group('NodeOccupancy — slotIndex (T007)', () {
    test('returns 0 for the first company', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      expect(occ.slotIndex('co1'), 0);
    });

    test('returns 1 for the second company', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      expect(occ.slotIndex('co2'), 1);
    });

    test('returns 2 for the third company', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      expect(occ.slotIndex('co3'), 2);
    });

    test('returns null if id is absent', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2']);
      expect(occ.slotIndex('co99'), isNull);
    });

    test('returns null on empty list', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: []);
      expect(occ.slotIndex('co1'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // T008: contains — returns true/false correctly
  // -------------------------------------------------------------------------

  group('NodeOccupancy — contains (T008)', () {
    test('returns true if id is present', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2']);
      expect(occ.contains('co1'), isTrue);
      expect(occ.contains('co2'), isTrue);
    });

    test('returns false if id is absent', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2']);
      expect(occ.contains('co99'), isFalse);
    });

    test('returns false on empty list', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: []);
      expect(occ.contains('co1'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // T009: departure and re-arrival produces correct compacted order
  // -------------------------------------------------------------------------

  group('NodeOccupancy — departure then re-arrival (T009)', () {
    test('departed company re-arriving appends at end', () {
      // co1, co2, co3 initially
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      // co1 departs → [co2, co3]
      final afterDeparture = occ.withDeparture('co1');
      expect(afterDeparture.orderedIds, ['co2', 'co3']);
      // co1 re-arrives → [co2, co3, co1]
      final afterReArrival = afterDeparture.withArrival('co1');
      expect(afterReArrival.orderedIds, ['co2', 'co3', 'co1']);
    });

    test('middle company departs and re-arrives at end', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      final afterDeparture = occ.withDeparture('co2');
      expect(afterDeparture.orderedIds, ['co1', 'co3']);
      final afterReArrival = afterDeparture.withArrival('co2');
      expect(afterReArrival.orderedIds, ['co1', 'co3', 'co2']);
    });

    test('last company departs and re-arrives — ends up at end again', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2', 'co3']);
      final afterDeparture = occ.withDeparture('co3');
      expect(afterDeparture.orderedIds, ['co1', 'co2']);
      final afterReArrival = afterDeparture.withArrival('co3');
      expect(afterReArrival.orderedIds, ['co1', 'co2', 'co3']);
    });

    test('all companies depart and one re-arrives — occupies slot 0', () {
      final occ = NodeOccupancy(nodeId: 'nodeA', orderedIds: ['co1', 'co2']);
      final empty = occ.withDeparture('co1').withDeparture('co2');
      expect(empty.orderedIds, isEmpty);
      final reArrived = empty.withArrival('co2');
      expect(reArrived.orderedIds, ['co2']);
      expect(reArrived.slotIndex('co2'), 0);
    });
  });

  // -------------------------------------------------------------------------
  // T010: _deriveOccupancy — sorts stationary companies lexicographically
  // -------------------------------------------------------------------------

  group('NodeOccupancy — _deriveOccupancy cold-start (T010)', () {
    test('sorts stationary companies at a node lexicographically by id', () {
      final companies = [
        _makeCompany(id: 'co_zeta', currentNode: _nodeA),
        _makeCompany(id: 'co_alpha', currentNode: _nodeA),
        _makeCompany(id: 'co_mid', currentNode: _nodeA),
      ];
      final occ = deriveOccupancy('nodeA', companies);
      expect(occ.orderedIds, ['co_alpha', 'co_mid', 'co_zeta']);
    });

    test('excludes in-transit companies from the derived occupancy', () {
      final companies = [
        _makeCompany(id: 'co1', currentNode: _nodeA), // stationary
        _makeCompany(id: 'co2', currentNode: _nodeA, destination: _nodeB), // in transit
      ];
      final occ = deriveOccupancy('nodeA', companies);
      expect(occ.orderedIds, ['co1']);
      expect(occ.contains('co2'), isFalse);
    });

    test('company with destination == currentNode is stationary', () {
      final companies = [
        _makeCompany(id: 'co1', currentNode: _nodeA, destination: _nodeA),
      ];
      final occ = deriveOccupancy('nodeA', companies);
      expect(occ.orderedIds, ['co1']);
    });

    test('empty result when no stationary companies at node', () {
      final companies = [
        _makeCompany(id: 'co1', currentNode: _nodeA, destination: _nodeB),
      ];
      final occ = deriveOccupancy('nodeA', companies);
      expect(occ.orderedIds, isEmpty);
    });

    test('only includes companies at the specified node', () {
      final companies = [
        _makeCompany(id: 'co1', currentNode: _nodeA),
        _makeCompany(id: 'co2', currentNode: _nodeB),
      ];
      final occ = deriveOccupancy('nodeA', companies);
      expect(occ.orderedIds, ['co1']);
    });

    test('produces same ordering on repeated calls (determinism)', () {
      final companies = [
        _makeCompany(id: 'co_b', currentNode: _nodeA),
        _makeCompany(id: 'co_a', currentNode: _nodeA),
      ];
      final occ1 = deriveOccupancy('nodeA', companies);
      final occ2 = deriveOccupancy('nodeA', companies);
      expect(occ1.orderedIds, occ2.orderedIds);
    });
  });
}
