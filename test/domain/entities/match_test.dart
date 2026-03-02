import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

GameMap _makeMinimalMap() {
  const nodeA = CastleNode(id: 'A', x: 0.0, y: 0.0, ownership: Ownership.player);
  const nodeB = CastleNode(id: 'B', x: 100.0, y: 0.0, ownership: Ownership.ai);
  final edgeAB = RoadEdge(from: nodeA, to: nodeB, length: 100.0);
  final edgeBA = RoadEdge(from: nodeB, to: nodeA, length: 100.0);
  return GameMap(nodes: [nodeA, nodeB], edges: [edgeAB, edgeBA]);
}

void main() {
  group('Match', () {
    group('construction', () {
      test('can be constructed with valid GameMap and players', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );
        expect(match.map, equals(map));
        expect(match.humanPlayer, equals(Ownership.player));
      });

      test('humanPlayer cannot be neutral', () {
        final map = _makeMinimalMap();
        expect(
          () => Match(
            map: map,
            humanPlayer: Ownership.neutral,
            phase: MatchPhase.playing,
          ),
          throwsArgumentError,
        );
      });
    });

    group('elapsed time', () {
      test('elapsed time starts at zero', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );
        expect(match.elapsedTime, equals(Duration.zero));
      });
    });

    group('win condition', () {
      test('win condition is totalConquest', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );
        expect(match.winCondition, equals(WinCondition.totalConquest));
      });
    });

    group('distinct players', () {
      test('human player is player ownership, not ai', () {
        final map = _makeMinimalMap();
        final match = Match(
          map: map,
          humanPlayer: Ownership.player,
          phase: MatchPhase.playing,
        );
        // The two players are player and ai — they are distinct
        expect(match.humanPlayer, isNot(equals(Ownership.ai)));
      });
    });

    group('MatchPhase', () {
      test('all phases exist', () {
        expect(MatchPhase.values.length, greaterThanOrEqualTo(3));
      });

      test('setup phase exists', () => expect(MatchPhase.setup, isA<MatchPhase>()));
      test('playing phase exists', () => expect(MatchPhase.playing, isA<MatchPhase>()));
      test('ended phase exists', () => expect(MatchPhase.ended, isA<MatchPhase>()));
    });
  });
}
