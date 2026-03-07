import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
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
  /// Last known battle snapshot — used by [_BattleSummary] when the
  /// [ActiveBattle] is gone from MatchState but no resolved entry exists yet
  /// (legacy / test fallback path).
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
            // Cache the live battle so we have a fallback snapshot.
            _lastBattle = activeBattle.battle;
          }

          // Battle resolved — prefer the authoritative resolved snapshot from
          // MatchState.resolvedBattles (set atomically by advanceBattleRound).
          if (activeBattle == null) {
            final resolvedBattle =
                matchState.resolvedBattles[battleId] ?? _lastBattle;
            if (resolvedBattle != null) {
              return _BattleSummary(battle: resolvedBattle);
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
      return _BattleSummary(battle: result.finalBattle);
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

  const _BattleSummary({required this.battle});

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

    // Compute per-role totals for each side, initial vs. final.
    final initialAttackers =
        battle.initialAttackers ?? battle.attackers;
    final initialDefenders =
        battle.initialDefenders ?? battle.defenders;

    final initialAttackerCounts = _mergeCounts(initialAttackers);
    final finalAttackerCounts = _mergeCounts(battle.attackers);
    final initialDefenderCounts = _mergeCounts(initialDefenders);
    final finalDefenderCounts = _mergeCounts(battle.defenders);

    return Scaffold(
      backgroundColor: const Color(0xFF1B1B2F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Outcome banner
              Text(
                outcomeText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: outcomeColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Battle ended after Round ${battle.roundNumber}',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              // Troop summary
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TroopSummaryColumn(
                        label: 'Attackers',
                        labelColor: outcome == BattleOutcome.attackersWin
                            ? const Color(0xFFFFD700)
                            : Colors.white70,
                        initialCounts: initialAttackerCounts,
                        finalCounts: finalAttackerCounts,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TroopSummaryColumn(
                        label: 'Defenders',
                        labelColor: outcome == BattleOutcome.defendersWin
                            ? const Color(0xFFFFD700)
                            : Colors.white70,
                        initialCounts: initialDefenderCounts,
                        finalCounts: finalDefenderCounts,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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

  /// Merges composition maps from a list of [Company]s into a single
  /// role → count map (summing counts across companies).
  static Map<UnitRole, int> _mergeCounts(List<Company> companies) {
    final result = <UnitRole, int>{};
    for (final co in companies) {
      for (final entry in co.composition.entries) {
        if (entry.value > 0) {
          result[entry.key] = (result[entry.key] ?? 0) + entry.value;
        }
      }
    }
    return result;
  }
}

/// A column displaying the troop counts (initial → final) for one battle side.
class _TroopSummaryColumn extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Map<UnitRole, int> initialCounts;
  final Map<UnitRole, int> finalCounts;

  const _TroopSummaryColumn({
    required this.label,
    required this.labelColor,
    required this.initialCounts,
    required this.finalCounts,
  });

  @override
  Widget build(BuildContext context) {
    // Show all roles that appeared in either initial or final counts.
    final allRoles = {
      ...initialCounts.keys,
      ...finalCounts.keys,
    }.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // Total soldiers
    final initialTotal =
        initialCounts.values.fold(0, (s, n) => s + n);
    final finalTotal =
        finalCounts.values.fold(0, (s, n) => s + n);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Side label
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: labelColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const Divider(color: Colors.white24, height: 20),
          // Header row
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Unit',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  'Start',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  'End',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Per-role rows
          ...allRoles.map((role) {
            final start = initialCounts[role] ?? 0;
            final end = finalCounts[role] ?? 0;
            final lost = start - end;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _roleName(role),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$start',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$end',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: end == 0
                            ? Colors.red.shade300
                            : end < start
                                ? Colors.orange.shade300
                                : Colors.green.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: Colors.white24, height: 20),
          // Total row
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$initialTotal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$finalTotal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: finalTotal == 0
                        ? Colors.red.shade300
                        : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleName(UnitRole role) {
    switch (role) {
      case UnitRole.peasant:
        return 'Peasant';
      case UnitRole.warrior:
        return 'Warrior';
      case UnitRole.knight:
        return 'Knight';
      case UnitRole.archer:
        return 'Archer';
      case UnitRole.catapult:
        return 'Catapult';
    }
  }
}
