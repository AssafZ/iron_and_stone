import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/state/castle_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';
import 'package:iron_and_stone/ui/widgets/deployment_panel.dart';

/// Screen showing a castle's garrison, stats, and deployment interface.
///
/// Watches [CastleNotifier] for live garrison counts and [MatchNotifier] for
/// the castle node reference. Embeds [DeploymentPanel] for company deployment.
///
/// Contains no game-rule logic — delegates entirely to notifiers and use cases.
class CastleScreen extends ConsumerWidget {
  const CastleScreen({super.key, required this.castleId});

  final String castleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchNotifierProvider);
    final castleListAsync = ref.watch(castleNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Castle'),
        backgroundColor: AppTheme.ironDark,
        foregroundColor: AppTheme.parchment,
      ),
      backgroundColor: AppTheme.parchment,
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (matchState) => castleListAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (castleList) {
            final castleState = castleList
                .where((c) => c.id == castleId)
                .firstOrNull;

            if (castleState == null) {
              return const Center(child: Text('Castle not found.'));
            }

            // Resolve the CastleNode from the map.
            final castleNode = matchState.match.map.nodes
                .whereType<CastleNode>()
                .where((n) => n.id == castleId)
                .firstOrNull;

            if (castleNode == null) {
              return const Center(child: Text('Castle node not found.'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Castle stats card
                  _CastleStatsCard(castleState: castleState),
                  const SizedBox(height: 16),
                  // Garrison card
                  _GarrisonCard(castleState: castleState),
                  const SizedBox(height: 16),
                  // Deployment panel
                  Card(
                    elevation: 2,
                    color: AppTheme.parchment,
                    child: DeploymentPanel(
                      castleId: castleId,
                      castleNode: castleNode,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _CastleStatsCard extends StatelessWidget {
  const _CastleStatsCard({required this.castleState});

  final CastleState castleState;

  @override
  Widget build(BuildContext context) {
    final multiplier = castleState.growthRateMultiplier;
    final peasants = castleState.garrison[UnitRole.peasant] ?? 0;
    final bonusPct = ((multiplier - 1.0) * 100).round();

    return Card(
      elevation: 2,
      color: AppTheme.parchment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Castle Stats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.ironDark,
              ),
            ),
            const Divider(),
            _StatRow(
              label: 'Owner',
              value: castleState.ownership.name.toUpperCase(),
            ),
            _StatRow(
              label: 'Cap',
              value: '${castleState.effectiveCap} soldiers',
            ),
            _StatRow(
              label: 'Growth Rate',
              value: '${multiplier.toStringAsFixed(2)}× (${bonusPct > 0 ? '+' : ''}$bonusPct%)',
            ),
            _StatRow(
              label: 'Peasant Bonus',
              value: '$peasants Peasants → +$bonusPct% growth & cap',
            ),
          ],
        ),
      ),
    );
  }
}

class _GarrisonCard extends StatelessWidget {
  const _GarrisonCard({required this.castleState});

  final CastleState castleState;

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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppTheme.parchment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Garrison',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.ironDark,
              ),
            ),
            const Divider(),
            ...UnitRole.values.map((role) {
              final count = castleState.garrison[role] ?? 0;
              return _StatRow(
                label: _roleName(role),
                value: '$count / 50',
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.stone),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.ironDark,
            ),
          ),
        ],
      ),
    );
  }
}
