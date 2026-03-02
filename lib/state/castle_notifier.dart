import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
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
}

/// Notifier for garrison counts and castle ownership.
///
/// Reads its source of truth from [matchNotifierProvider] and exposes a
/// read-optimised [List<CastleState>] for widgets.
///
/// Growth ticking is owned by [MatchNotifier]/[TickMatch]; this notifier
/// provides a convenient watch target for the UI without duplicating state.
class CastleNotifier extends AsyncNotifier<List<CastleState>> {
  @override
  Future<List<CastleState>> build() async {
    // Listen to MatchNotifier so we stay in sync.
    final matchState = await ref.watch(matchNotifierProvider.future);
    return matchState.castles.map((c) => CastleState(castle: c)).toList();
  }
}

/// The global [CastleNotifier] provider.
final castleNotifierProvider =
    AsyncNotifierProvider<CastleNotifier, List<CastleState>>(CastleNotifier.new);
