import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/tick_castle_growth.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

/// Lightweight view-model for a single castle.
final class CastleState {
  final Castle castle;

  const CastleState({required this.castle});

  String get id => castle.id;
  Ownership get ownership => castle.ownership;
  int get effectiveCap => castle.effectiveCap;
  double get growthRateMultiplier => castle.growthRateMultiplier;
  Map<UnitRole, int> get garrison => castle.garrison;
}

/// Notifier for garrison counts and castle ownership.
///
/// Reads its source of truth from [matchNotifierProvider] and exposes a
/// read-optimised [List<CastleState>] for widgets.
///
/// Provides [tickGrowth] to apply a single growth tick to all castles.
/// Growth is also triggered automatically via [MatchNotifier]/[TickMatch];
/// this action exists for direct control from widget tests and the UI.
class CastleNotifier extends AsyncNotifier<List<CastleState>> {
  @override
  Future<List<CastleState>> build() async {
    // Listen to MatchNotifier so we stay in sync.
    final matchState = await ref.watch(matchNotifierProvider.future);
    return matchState.castles.map((c) => CastleState(castle: c)).toList();
  }

  /// Apply one growth tick to all castles and sync back to [MatchNotifier].
  Future<void> tickGrowth() async {
    final current = state.valueOrNull;
    if (current == null) return;

    const useCase = TickCastleGrowth();
    final grown = current.map((cs) {
      final updated = useCase.tick(cs.castle);
      return CastleState(castle: updated);
    }).toList();

    state = AsyncData(grown);

    // Sync updated castles back into MatchNotifier.
    for (final cs in grown) {
      ref.read(matchNotifierProvider.notifier).updateCastle(cs.castle);
    }
  }
}

/// The global [CastleNotifier] provider.
final castleNotifierProvider =
    AsyncNotifierProvider<CastleNotifier, List<CastleState>>(CastleNotifier.new);
