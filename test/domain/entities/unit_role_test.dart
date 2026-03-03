import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';

void main() {
  group('UnitRole', () {
    group('all five roles exist', () {
      test('Peasant exists', () => expect(UnitRole.peasant, isA<UnitRole>()));
      test('Warrior exists', () => expect(UnitRole.warrior, isA<UnitRole>()));
      test('Knight exists', () => expect(UnitRole.knight, isA<UnitRole>()));
      test('Archer exists', () => expect(UnitRole.archer, isA<UnitRole>()));
      test('Catapult exists', () => expect(UnitRole.catapult, isA<UnitRole>()));
      test('exactly five roles exist', () => expect(UnitRole.values.length, equals(5)));
    });

    group('Peasant stats (FR-016, FR-009)', () {
      test('hp is 10', () => expect(UnitRole.peasant.hp, equals(10)));
      test('damage is 0', () => expect(UnitRole.peasant.damage, equals(0)));
      test('speed is 5', () => expect(UnitRole.peasant.speed, equals(5)));
      test('range is 1 (melee)', () => expect(UnitRole.peasant.range, equals(1)));
      test('has specialAbility tag', () => expect(UnitRole.peasant.specialAbility, isNotNull));
    });

    group('Warrior stats (FR-016, FR-009)', () {
      test('hp is 50', () => expect(UnitRole.warrior.hp, equals(50)));
      test('damage is 15', () => expect(UnitRole.warrior.damage, equals(15)));
      test('speed is 6', () => expect(UnitRole.warrior.speed, equals(6)));
      test('range is 1 (melee)', () => expect(UnitRole.warrior.range, equals(1)));
    });

    group('Knight stats (FR-016, FR-009)', () {
      test('hp is 100', () => expect(UnitRole.knight.hp, equals(100)));
      test('damage is 40', () => expect(UnitRole.knight.damage, equals(40)));
      test('speed is 10', () => expect(UnitRole.knight.speed, equals(10)));
      test('range is 1 (melee)', () => expect(UnitRole.knight.range, equals(1)));
      test('has specialAbility tag', () => expect(UnitRole.knight.specialAbility, isNotNull));
    });

    group('Archer stats (FR-016, FR-009)', () {
      test('hp is 30', () => expect(UnitRole.archer.hp, equals(30)));
      test('damage is 25', () => expect(UnitRole.archer.damage, equals(25)));
      test('speed is 6', () => expect(UnitRole.archer.speed, equals(6)));
      test('range is 3 (ranged)', () => expect(UnitRole.archer.range, equals(3)));
      test('has specialAbility tag', () => expect(UnitRole.archer.specialAbility, isNotNull));
    });

    group('Catapult stats (FR-016, FR-009)', () {
      test('hp is 150', () => expect(UnitRole.catapult.hp, equals(150)));
      test('damage is 60', () => expect(UnitRole.catapult.damage, equals(60)));
      test('speed is 3', () => expect(UnitRole.catapult.speed, equals(3)));
      test('range is 5 (siege)', () => expect(UnitRole.catapult.range, equals(5)));
      test('has specialAbility tag', () => expect(UnitRole.catapult.specialAbility, isNotNull));
    });

    group('melee vs ranged classification', () {
      test('Peasant is melee (range == 1)', () => expect(UnitRole.peasant.range, equals(1)));
      test('Warrior is melee (range == 1)', () => expect(UnitRole.warrior.range, equals(1)));
      test('Knight is melee (range == 1)', () => expect(UnitRole.knight.range, equals(1)));
      test('Archer is ranged (range > 1)', () => expect(UnitRole.archer.range, greaterThan(1)));
      test('Catapult is ranged (range > 1)', () => expect(UnitRole.catapult.range, greaterThan(1)));
    });
  });
}
