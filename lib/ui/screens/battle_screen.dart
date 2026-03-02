import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/state/battle_notifier.dart';
import 'package:iron_and_stone/ui/widgets/battle_side_view.dart';

/// Full-screen battle view.
///
/// Shows both sides via [BattleSideView], a "Next Round" button,
/// and transitions to an inline summary once the battle is resolved.
final class BattleScreen extends ConsumerWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battleState = ref.watch(battleNotifierProvider);
    final battle = battleState.battle;
    final result = battleState.result;

    // Battle resolved — show summary
    if (result != null) {
      return _BattleSummary(battle: battle, result: result);
    }

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
                  onPressed: () =>
                      ref.read(battleNotifierProvider.notifier).advanceRound(),
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
