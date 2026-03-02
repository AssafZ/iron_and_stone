import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/value_objects/soldier_count.dart';

void main() {
  group('Company', () {
    group('composition map integrity', () {
      test('can be constructed with a single role', () {
        final company = Company(
          composition: {UnitRole.warrior: 10},
        );
        expect(company.composition[UnitRole.warrior], equals(10));
      });

      test('can be constructed with multiple roles', () {
        final company = Company(
          composition: {UnitRole.warrior: 5, UnitRole.archer: 3},
        );
        expect(company.composition[UnitRole.warrior], equals(5));
        expect(company.composition[UnitRole.archer], equals(3));
      });

      test('zero-count roles are ignored in composition', () {
        final company = Company(
          composition: {UnitRole.warrior: 5, UnitRole.knight: 0},
        );
        // Zero-count roles should not contribute to totalSoldiers
        expect(company.totalSoldiers.value, equals(5));
      });
    });

    group('totalSoldiers cap enforcement', () {
      test('totalSoldiers equals sum of composition values', () {
        final company = Company(
          composition: {UnitRole.warrior: 20, UnitRole.archer: 15},
        );
        expect(company.totalSoldiers, equals(SoldierCount(35)));
      });

      test('totalSoldiers at exactly 50 is accepted', () {
        final company = Company(
          composition: {UnitRole.warrior: 25, UnitRole.knight: 25},
        );
        expect(company.totalSoldiers.value, equals(50));
      });

      test('totalSoldiers exceeding 50 throws ArgumentError', () {
        expect(
          () => Company(composition: {UnitRole.warrior: 30, UnitRole.knight: 21}),
          throwsArgumentError,
        );
      });

      test('empty composition has totalSoldiers of 0', () {
        final company = Company(composition: {});
        expect(company.totalSoldiers.value, equals(0));
      });
    });

    group('movementSpeed', () {
      test('movementSpeed is the minimum speed of roles present', () {
        // Warrior speed=6, Catapult speed=3 → min is 3
        final company = Company(
          composition: {UnitRole.warrior: 10, UnitRole.catapult: 5},
        );
        expect(company.movementSpeed, equals(3));
      });

      test('single role movementSpeed equals that role speed', () {
        final company = Company(composition: {UnitRole.knight: 10});
        expect(company.movementSpeed, equals(UnitRole.knight.speed));
      });

      test('warrior + catapult → speed is catapult speed (3)', () {
        // Acceptance Scenario 4 from spec: Warriors (speed 6) + Catapults (speed 3) → 3
        final company = Company(
          composition: {UnitRole.warrior: 1, UnitRole.catapult: 1},
        );
        expect(company.movementSpeed, equals(3));
      });

      test('all roles present → speed equals slowest (catapult, 3)', () {
        final company = Company(
          composition: {
            UnitRole.peasant: 2,
            UnitRole.warrior: 2,
            UnitRole.knight: 2,
            UnitRole.archer: 2,
            UnitRole.catapult: 2,
          },
        );
        expect(company.movementSpeed, equals(3));
      });

      test('empty company movementSpeed returns 0', () {
        final company = Company(composition: {});
        expect(company.movementSpeed, equals(0));
      });
    });

    group('immutability and copyWith', () {
      test('copyWith updates a role count', () {
        final original = Company(composition: {UnitRole.warrior: 10});
        final updated = original.copyWith(
          composition: {UnitRole.warrior: 20},
        );
        expect(updated.composition[UnitRole.warrior], equals(20));
        expect(original.composition[UnitRole.warrior], equals(10));
      });
    });
  });
}
