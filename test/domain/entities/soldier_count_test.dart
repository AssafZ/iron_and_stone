import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/value_objects/soldier_count.dart';

void main() {
  group('SoldierCount', () {
    group('valid construction', () {
      test('can be constructed at 0 (lower bound)', () {
        final count = SoldierCount(0);
        expect(count.value, equals(0));
      });

      test('can be constructed at 50 (upper bound)', () {
        final count = SoldierCount(50);
        expect(count.value, equals(50));
      });

      test('can be constructed at midrange value', () {
        final count = SoldierCount(25);
        expect(count.value, equals(25));
      });
    });

    group('invalid construction', () {
      test('throws ArgumentError for -1 (below lower bound)', () {
        expect(() => SoldierCount(-1), throwsArgumentError);
      });

      test('throws ArgumentError for 51 (above upper bound)', () {
        expect(() => SoldierCount(51), throwsArgumentError);
      });

      test('throws ArgumentError for large negative value', () {
        expect(() => SoldierCount(-100), throwsArgumentError);
      });

      test('throws ArgumentError for large positive value', () {
        expect(() => SoldierCount(1000), throwsArgumentError);
      });
    });

    group('equality', () {
      test('two SoldierCounts with same value are equal', () {
        expect(SoldierCount(10), equals(SoldierCount(10)));
      });

      test('two SoldierCounts with different values are not equal', () {
        expect(SoldierCount(10), isNot(equals(SoldierCount(20))));
      });

      test('hashCode is consistent with equality', () {
        expect(SoldierCount(10).hashCode, equals(SoldierCount(10).hashCode));
      });
    });
  });
}
