import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/rules/ai_controller.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

/// Thin Riverpod wrapper that calls [AiController.decide] and dispatches the
/// resulting [AiAction] to the appropriate notifiers.
///
/// Contains NO decision logic — all intelligence lives in [AiController].
class AiControllerNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Called by [MatchNotifier] after each game-loop tick to let the AI act.
  ///
  /// Reads current [MatchState], delegates to [AiController.decide], then
  /// dispatches the resulting [AiAction] to [CompanyNotifier] or
  /// [CastleNotifier] as appropriate.
  Future<void> act() async {
    final matchState = ref.read(matchNotifierProvider).valueOrNull;
    if (matchState == null) return;

    final action = const AiController().decide(
      map: matchState.match.map,
      castles: matchState.castles,
      companies: matchState.companies,
    );

    switch (action) {
      case DeployAction(:final castleId, :final composition):
        // Find the CastleNode corresponding to the AI castle.
        final castleNode = matchState.match.map.nodes
            .whereType<CastleNode>()
            .where((n) => n.id == castleId)
            .firstOrNull;
        if (castleNode == null) return;

        await ref.read(companyNotifierProvider.notifier).deployCompany(
              castleId: castleId,
              castleNode: castleNode,
              composition: composition,
              map: matchState.match.map,
            );

      case MoveAction(:final companyId, :final destination):
        await ref.read(companyNotifierProvider.notifier).setDestination(
              companyId: companyId,
              destination: destination,
              map: matchState.match.map,
            );

      case NoAction():
        // Nothing to do this tick.
        break;
    }
  }
}

/// Global provider for [AiControllerNotifier].
final aiControllerNotifierProvider =
    NotifierProvider<AiControllerNotifier, void>(AiControllerNotifier.new);
