import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/state/battle_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/widgets/battle_side_view.dart';

/// Full-screen battle view.
///
/// When [battleId] is provided the screen watches [matchNotifierProvider] and
/// derives its state from the matching [ActiveBattle].  Once the battle is
/// resolved (removed from `activeBattles`) the screen transitions to
/// [_BattleSummary] using the last-known [Battle] snapshot stored in local
/// widget state.
///
/// When [battleId] is `null` the screen falls back to the legacy
/// [battleNotifierProvider] so existing tests continue to pass.
final class BattleScreen extends ConsumerStatefulWidget {
  /// Identifies the active battle in [MatchState.activeBattles].
  final String? battleId;

  const BattleScreen({super.key, this.battleId});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

final class _BattleScreenState extends ConsumerState<BattleScreen> {
  /// Last known battle snapshot — used by [_BattleSummary] after the
  /// [ActiveBattle] is removed from state on resolution.
  Battle? _lastBattle;

  @override
  Widget build(BuildContext context) {
    final battleId = widget.battleId;

    // ── matchNotifier path (T043) ───────────────────────────────────────────
    if (battleId != null) {
      final matchAsync = ref.watch(matchNotifierProvider);
      return matchAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text('Error: $e'))),
        data: (matchState) {
          final activeBattle = matchState.activeBattles
              .firstWhereOrNull((b) => b.id == battleId);

          if (activeBattle != null) {
            // Cache the live battle so we can show it in _BattleSummary after
            // the battle is resolved.
            _lastBattle = activeBattle.battle;
          }

          // Battle resolved (T042) — show summary using last-known snapshot.
          if (activeBattle == null) {
            final snapshot = _lastBattle;
            if (snapshot != null) {
              return _BattleSummary(
                  battle: snapshot,
                  result: snapshot.outcome ?? BattleOutcome.draw);
            }
            // Fallback if we never saw the battle (shouldn't happen in practice).
            return const Scaffold(
              body: Center(child: Text('Battle not found')),
            );
          }

          final battle = activeBattle.battle;
          return _buildBattleScaffold(
            battle: battle,
            onNextRound: () => ref
                .read(matchNotifierProvider.notifier)
                .advanceBattleRound(battleId),
          );
        },
      );
    }

    // ── Legacy battleNotifierProvider path (existing tests) ─────────────────
    final battleState = ref.watch(battleNotifierProvider);
    final battle = battleState.battle;
    final result = battleState.result;

    if (result != null) {
      return _BattleSummary(battle: battle, result: result);
    }

    return _buildBattleScaffold(
      battle: battle,
      onNextRound: () =>
          ref.read(battleNotifierProvider.notifier).advanceRound(),
    );
  }

  Widget _buildBattleScaffold({
    required Battle battle,
    required VoidCallback onNextRound,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B2F),
        title: Text(
          'Round ${battle.roundNumber}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: BattleSideView(
                        companies: battle.attackers,
                        label: 'Attackers',
                      ),
                    ),
                    const SizedBox(width: 16),
                    const _VsLabel(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BattleSideView(
                        companies: battle.defenders,
                        label: 'Defenders',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (battle.roundLog.isNotEmpty)
                _RoundLogEntry(entry: battle.roundLog.last),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNextRound,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Next Round',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VsLabel extends StatelessWidget {
  const _VsLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'VS',
      style: TextStyle(
        color: Colors.orange,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }
}

class _RoundLogEntry extends StatelessWidget {
  final String entry;

  const _RoundLogEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        entry,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _BattleSummary extends StatelessWidget {
  final Battle battle;
  final Object result; // BattleResult

  const _BattleSummary({required this.battle, required this.result});

  @override
  Widget build(BuildContext context) {
    final outcome = battle.outcome;

    final String outcomeText;
    final Color outcomeColor;
    if (outcome == BattleOutcome.attackersWin) {
      outcomeText = 'Victory';
      outcomeColor = const Color(0xFFFFD700);
    } else if (outcome == BattleOutcome.defendersWin) {
      outcomeText = 'Defeat';
      outcomeColor = const Color(0xFFB71C1C);
    } else {
      outcomeText = 'Draw';
      outcomeColor = Colors.orange;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B1B2F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                outcomeText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: outcomeColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Battle ended after Round ${battle.roundNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Return to Map',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
