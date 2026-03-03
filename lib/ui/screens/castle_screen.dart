import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/castle_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

/// Screen showing a castle's stats and companies stationed here.
///
/// Castles have no garrison pool — soldiers live only in companies.
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

            // Companies currently stationed at this castle node.
            final stationedCompanies = matchState.companies
                .where((co) =>
                    co.currentNode.id == castleId &&
                    co.destination == null)
                .toList();

            // All companies at this node (including those passing through).
            final allCompaniesHere = matchState.companies
                .where((co) => co.currentNode.id == castleId)
                .toList();

            // Peasant count from stationed companies (drives growth rate).
            final peasantsInCompanies = stationedCompanies.fold<int>(
              0,
              (sum, co) => sum + (co.company.composition[UnitRole.peasant] ?? 0),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Castle stats card
                  _CastleStatsCard(
                    castleState: castleState,
                    peasantsInCompanies: peasantsInCompanies,
                  ),
                  const SizedBox(height: 16),
                  // Companies at this castle
                  if (allCompaniesHere.isNotEmpty)
                    _CompaniesCard(
                      companies: allCompaniesHere,
                      castleId: castleId,
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

class _CompaniesCard extends StatelessWidget {
  const _CompaniesCard({required this.companies, required this.castleId});

  final List<CompanyOnMap> companies;
  final String castleId;

  String _roleName(UnitRole role) {
    switch (role) {
      case UnitRole.peasant:
        return 'Peasants';
      case UnitRole.warrior:
        return 'Warriors';
      case UnitRole.knight:
        return 'Knights';
      case UnitRole.archer:
        return 'Archers';
      case UnitRole.catapult:
        return 'Catapults';
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
            Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.ironDark, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Companies here (${companies.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ironDark,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...companies.asMap().entries.map((entry) {
              final idx = entry.key;
              final co = entry.value;
              final isPlayer = co.ownership == Ownership.player;
              final ownerLabel = isPlayer ? 'Your company' : 'Enemy company';
              final ownerColor = isPlayer ? AppTheme.bloodRed : AppTheme.midnightBlue;
              final total = co.company.totalSoldiers.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: ownerColor.withAlpha(80)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: ownerColor,
                      radius: 16,
                      child: Text(
                        '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '$ownerLabel — $total soldiers',
                      style: TextStyle(
                        color: AppTheme.ironDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: co.destination != null
                        ? Text(
                            'Marching to: ${co.destination!.id}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.stone,
                            ),
                          )
                        : const Text(
                            'Stationed here',
                            style: TextStyle(fontSize: 12, color: AppTheme.stone),
                          ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          children: UnitRole.values
                              .where((r) => (co.company.composition[r] ?? 0) > 0)
                              .map((role) {
                            final count = co.company.composition[role] ?? 0;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _roleName(role),
                                  style: const TextStyle(color: AppTheme.stone),
                                ),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: AppTheme.ironDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CastleStatsCard extends StatelessWidget {
  const _CastleStatsCard({
    required this.castleState,
    required this.peasantsInCompanies,
  });

  final CastleState castleState;
  final int peasantsInCompanies;

  @override
  Widget build(BuildContext context) {
    final multiplier = 1.0 + 0.05 * peasantsInCompanies;
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
              label: 'Peasants in Companies',
              value: '$peasantsInCompanies → +$bonusPct% growth & cap',
            ),
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
