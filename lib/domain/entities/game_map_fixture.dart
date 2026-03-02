import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// Hardcoded fixed game map for the MVP single-player match.
///
/// Layout (x-axis):
/// ```
/// [PlayerCastle] —100— [J1] —100— [J2] —100— [J3] —100— [J4] —100— [AiCastle]
///                                   \___100___/
/// ```
/// 6 nodes total: 2 [CastleNode]s + 4 [RoadJunctionNode]s.
/// All edges are bidirectional (stored as two directed edges each).
abstract final class GameMapFixture {
  static const String playerCastleId = 'player_castle';
  static const String aiCastleId = 'ai_castle';

  // Nodes
  static const _playerCastle = CastleNode(
    id: playerCastleId,
    x: 0.0,
    y: 0.0,
    ownership: Ownership.player,
  );

  static const _j1 = RoadJunctionNode(id: 'j1', x: 100.0, y: 0.0);
  static const _j2 = RoadJunctionNode(id: 'j2', x: 200.0, y: 50.0);
  static const _j3 = RoadJunctionNode(id: 'j3', x: 200.0, y: -50.0);
  static const _j4 = RoadJunctionNode(id: 'j4', x: 300.0, y: 0.0);

  static const _aiCastle = CastleNode(
    id: aiCastleId,
    x: 400.0,
    y: 0.0,
    ownership: Ownership.ai,
  );

  /// Builds and returns the fixed [GameMap] for the MVP match.
  static GameMap build() {
    final edges = <RoadEdge>[
      // Player castle ↔ J1
      RoadEdge(from: _playerCastle, to: _j1, length: 100.0),
      RoadEdge(from: _j1, to: _playerCastle, length: 100.0),
      // J1 ↔ J2
      RoadEdge(from: _j1, to: _j2, length: 112.0),
      RoadEdge(from: _j2, to: _j1, length: 112.0),
      // J1 ↔ J3
      RoadEdge(from: _j1, to: _j3, length: 112.0),
      RoadEdge(from: _j3, to: _j1, length: 112.0),
      // J2 ↔ J4
      RoadEdge(from: _j2, to: _j4, length: 112.0),
      RoadEdge(from: _j4, to: _j2, length: 112.0),
      // J3 ↔ J4
      RoadEdge(from: _j3, to: _j4, length: 112.0),
      RoadEdge(from: _j4, to: _j3, length: 112.0),
      // J4 ↔ AI castle
      RoadEdge(from: _j4, to: _aiCastle, length: 112.0),
      RoadEdge(from: _aiCastle, to: _j4, length: 112.0),
    ];

    return GameMap(
      nodes: [_playerCastle, _j1, _j2, _j3, _j4, _aiCastle],
      edges: edges,
    );
  }
}
