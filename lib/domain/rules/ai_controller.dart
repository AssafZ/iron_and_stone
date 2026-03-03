import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// AiAction sealed hierarchy
// ---------------------------------------------------------------------------

/// The result of [AiController.decide].
sealed class AiAction {
  const AiAction();
}

/// The AI should deploy a new Company with [composition] from [castleId].
final class DeployAction extends AiAction {
  final String castleId;
  final Map<UnitRole, int> composition;

  const DeployAction({required this.castleId, required this.composition});

  @override
  String toString() => 'DeployAction(castle=$castleId, composition=$composition)';
}

/// The AI should assign [destination] to the Company with [companyId].
final class MoveAction extends AiAction {
  final String companyId;

  /// The target [MapNode] — always a non-AI castle for the MVP.
  final MapNode destination;

  const MoveAction({required this.companyId, required this.destination});

  @override
  String toString() =>
      'MoveAction(company=$companyId, destination=${destination.id})';
}

/// The AI has nothing to do this tick.
final class NoAction extends AiAction {
  const NoAction();

  @override
  String toString() => 'NoAction()';
}

// ---------------------------------------------------------------------------
// AiController
// ---------------------------------------------------------------------------

/// Deterministic rule-based AI decision engine (pure Dart, zero Flutter/state
/// imports).
///
/// Decision priority per tick:
/// 1. **Move** — when an AI Company exists without a destination, assign it to
///    march toward the nearest non-AI castle.
/// 2. **NoAction** — all Companies already have orders.
final class AiController {
  /// Maximum soldiers per Company (spec cap).
  static const int _companyCap = 50;

  const AiController();

  /// Evaluate the current match state and return a single [AiAction].
  ///
  /// Parameters are the domain primitives that the state layer assembles from
  /// [MatchState] before delegating here — keeping this class pure Dart with
  /// no state-layer imports.
  AiAction decide({
    required GameMap map,
    required List<Castle> castles,
    required List<CompanyOnMap> companies,
  }) {
    final aiCompanies = companies
        .where((c) => c.ownership == Ownership.ai)
        .toList();

    // Move any stationary AI Company toward the nearest non-AI castle.
    final stationaryCompany =
        aiCompanies.where((c) => c.destination == null).firstOrNull;

    if (stationaryCompany != null) {
      final target = _nearestNonAiCastle(
        from: stationaryCompany.currentNode,
        mapNodes: map.nodes,
      );
      if (target != null) {
        return MoveAction(
          companyId: stationaryCompany.id,
          destination: target,
        );
      }
    }

    return const NoAction();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Find the nearest castle node not owned by the AI, measured by Euclidean
  /// distance from [from].
  MapNode? _nearestNonAiCastle({
    required MapNode from,
    required List<MapNode> mapNodes,
  }) {
    // Filter to non-AI castle nodes.
    final targets = mapNodes.whereType<CastleNode>().where(
      (n) => n.ownership != Ownership.ai,
    );

    if (targets.isEmpty) return null;

    // Pick the one with the smallest Euclidean distance (squared, no sqrt needed).
    CastleNode? nearest;
    var bestDist = double.infinity;

    for (final target in targets) {
      final dx = target.x - from.x;
      final dy = target.y - from.y;
      final dist = dx * dx + dy * dy;
      if (dist < bestDist) {
        bestDist = dist;
        nearest = target;
      }
    }

    return nearest;
  }
}
