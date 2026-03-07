import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';

void main() {
  group('RoadPosition', () {
    group('valid construction', () {
      test('progress = 0.0 is valid', () {
        final pos = RoadPosition(
          currentNodeId: 'a',
          progress: 0.0,
          nextNodeId: 'b',
        );
        expect(pos.currentNodeId, equals('a'));
        expect(pos.progress, equals(0.0));
        expect(pos.nextNodeId, equals('b'));
      });

      test('progress = 0.5 is valid', () {
        final pos = RoadPosition(
          currentNodeId: 'a',
          progress: 0.5,
          nextNodeId: 'b',
        );
        expect(pos.progress, equals(0.5));
      });

      test('progress = 0.999 is valid', () {
        final pos = RoadPosition(
          currentNodeId: 'a',
          progress: 0.999,
          nextNodeId: 'b',
        );
        expect(pos.progress, equals(0.999));
      });

      test('progress = 0.9999 is valid', () {
        final pos = RoadPosition(
          currentNodeId: 'a',
          progress: 0.9999,
          nextNodeId: 'b',
        );
        expect(pos.progress, equals(0.9999));
      });
    });

    group('invalid construction', () {
      test('progress = 1.0 throws ArgumentError', () {
        expect(
          () => RoadPosition(
            currentNodeId: 'a',
            progress: 1.0,
            nextNodeId: 'b',
          ),
          throwsArgumentError,
        );
      });

      test('progress > 1.0 throws ArgumentError', () {
        expect(
          () => RoadPosition(
            currentNodeId: 'a',
            progress: 1.5,
            nextNodeId: 'b',
          ),
          throwsArgumentError,
        );
      });

      test('progress < 0.0 throws ArgumentError', () {
        expect(
          () => RoadPosition(
            currentNodeId: 'a',
            progress: -0.1,
            nextNodeId: 'b',
          ),
          throwsArgumentError,
        );
      });

      test('currentNodeId == nextNodeId throws ArgumentError', () {
        expect(
          () => RoadPosition(
            currentNodeId: 'a',
            progress: 0.5,
            nextNodeId: 'a',
          ),
          throwsArgumentError,
        );
      });
    });

    group('equality and hashCode', () {
      test('two equal RoadPositions are ==', () {
        final a = RoadPosition(currentNodeId: 'x', progress: 0.3, nextNodeId: 'y');
        final b = RoadPosition(currentNodeId: 'x', progress: 0.3, nextNodeId: 'y');
        expect(a, equals(b));
      });

      test('different progress makes them not equal', () {
        final a = RoadPosition(currentNodeId: 'x', progress: 0.3, nextNodeId: 'y');
        final b = RoadPosition(currentNodeId: 'x', progress: 0.4, nextNodeId: 'y');
        expect(a, isNot(equals(b)));
      });

      test('different currentNodeId makes them not equal', () {
        final a = RoadPosition(currentNodeId: 'x', progress: 0.3, nextNodeId: 'y');
        final b = RoadPosition(currentNodeId: 'z', progress: 0.3, nextNodeId: 'y');
        expect(a, isNot(equals(b)));
      });

      test('different nextNodeId makes them not equal', () {
        final a = RoadPosition(currentNodeId: 'x', progress: 0.3, nextNodeId: 'y');
        final b = RoadPosition(currentNodeId: 'x', progress: 0.3, nextNodeId: 'z');
        expect(a, isNot(equals(b)));
      });

      test('equal instances have the same hashCode', () {
        final a = RoadPosition(currentNodeId: 'x', progress: 0.3, nextNodeId: 'y');
        final b = RoadPosition(currentNodeId: 'x', progress: 0.3, nextNodeId: 'y');
        expect(a.hashCode, equals(b.hashCode));
      });
    });
  });
}
