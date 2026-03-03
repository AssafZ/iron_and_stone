import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  group('Ownership', () {
    group('values', () {
      test('player value exists', () {
        expect(Ownership.player, isA<Ownership>());
      });

      test('ai value exists', () {
        expect(Ownership.ai, isA<Ownership>());
      });

      test('neutral value exists', () {
        expect(Ownership.neutral, isA<Ownership>());
      });

      test('exactly three ownership values exist', () {
        expect(Ownership.values.length, equals(3));
      });
    });

    group('equality', () {
      test('same values are equal', () {
        expect(Ownership.player, equals(Ownership.player));
        expect(Ownership.ai, equals(Ownership.ai));
        expect(Ownership.neutral, equals(Ownership.neutral));
      });

      test('different values are not equal', () {
        expect(Ownership.player, isNot(equals(Ownership.ai)));
        expect(Ownership.player, isNot(equals(Ownership.neutral)));
        expect(Ownership.ai, isNot(equals(Ownership.neutral)));
      });
    });

    group('serialization round-trip', () {
      test('player serializes to "player" and deserializes back', () {
        const name = 'player';
        final deserialized = Ownership.fromString(name);
        expect(deserialized, equals(Ownership.player));
        expect(deserialized.name, equals(name));
      });

      test('ai serializes to "ai" and deserializes back', () {
        const name = 'ai';
        final deserialized = Ownership.fromString(name);
        expect(deserialized, equals(Ownership.ai));
        expect(deserialized.name, equals(name));
      });

      test('neutral serializes to "neutral" and deserializes back', () {
        const name = 'neutral';
        final deserialized = Ownership.fromString(name);
        expect(deserialized, equals(Ownership.neutral));
        expect(deserialized.name, equals(name));
      });

      test('fromString throws for unknown value', () {
        expect(() => Ownership.fromString('unknown'), throwsArgumentError);
      });

      test('all values round-trip correctly', () {
        for (final ownership in Ownership.values) {
          expect(Ownership.fromString(ownership.name), equals(ownership));
        }
      });
    });
  });
}
