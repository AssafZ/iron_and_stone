import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/castle_notifier.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';
import 'package:iron_and_stone/ui/widgets/split_slider.dart';

/// Screen showing a castle's stats and companies stationed here.
///
/// Castles have no garrison pool — soldiers live only in companies.
class CastleScreen extends ConsumerWidget {
  const CastleScreen({super.key, required this.castleId});

  final String castleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchNotifierProvider);

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
        data: (matchState) {
          // Derive castle state directly from matchState — avoids a secondary
          // castleNotifierProvider watch that transitions through AsyncLoading
          // on every matchNotifierProvider update, which destroys and recreates
          // _CompaniesRosterCardState and invalidates any captured refs.
          final castle =
              matchState.castles.where((c) => c.id == castleId).firstOrNull;

          if (castle == null) {
            return const Center(child: Text('Castle not found.'));
          }

          final castleState = CastleState(castle: castle);

          // Companies currently stationed at this castle node.
          final stationedCompanies = matchState.companies
              .where((co) =>
                  co.currentNode.id == castleId && co.destination == null)
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
                // Companies at this castle — roster (player) or read-only summary (enemy/neutral)
                if (castleState.ownership == Ownership.player) ...[
                  if (allCompaniesHere.isNotEmpty)
                    _CompaniesRosterCard(
                      companies: allCompaniesHere,
                      castleId: castleId,
                    ),
                ] else ...[
                  _EnemyDefenderSummary(
                    companies: stationedCompanies,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Roster card shown for player-owned castles.
///
/// Lists all companies currently at this castle node. Each row is individually
/// tappable and calls [companyNotifierProvider.selectCompany] on the selected
/// company. The "front" (selected) company is visually highlighted with a gold
/// border. Stationary companies are labelled "Garrisoned"; companies with an
/// active destination are labelled "Defending".
class _CompaniesRosterCard extends ConsumerStatefulWidget {
  const _CompaniesRosterCard({
    required this.companies,
    required this.castleId,
  });

  final List<CompanyOnMap> companies;
  final String castleId;

  @override
  ConsumerState<_CompaniesRosterCard> createState() =>
      _CompaniesRosterCardState();
}

class _CompaniesRosterCardState extends ConsumerState<_CompaniesRosterCard> {
  /// Index into [widget.companies] of the currently highlighted "front" company.
  int _frontIndex = 0;

  /// When non-null, we are in "merge mode": waiting for the user to pick a
  /// second company to merge with the one at [_mergeSourceIndex].
  int? _mergeSourceIndex;

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

  bool _isStationary(CompanyOnMap co) =>
      co.destination == null || co.destination!.id == co.currentNode.id;

  void _showMergePrompt(
    BuildContext context,
    CompanyOnMap a,
    CompanyOnMap b,
  ) {
    final totalA = a.company.totalSoldiers.value;
    final totalB = b.company.totalSoldiers.value;
    final combined = totalA + totalB;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.parchment,
        title: const Text(
          'Merge Companies?',
          style: TextStyle(color: AppTheme.ironDark),
        ),
        content: Text(
          'Merge Company ($totalA soldiers) with Company ($totalB soldiers)?\n'
          'Combined: $combined soldiers'
          '${combined > 50 ? " → primary of 50 + overflow of ${combined - 50}" : ""}.',
          style: const TextStyle(color: AppTheme.ironDark),
        ),
        actions: [
          TextButton(
            key: const ValueKey('castle_merge_cancel_button'),
            onPressed: () {
              setState(() => _mergeSourceIndex = null);
              Navigator.of(ctx).pop();
            },
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.stone)),
          ),
          ElevatedButton(
            key: const ValueKey('castle_merge_confirm_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bloodRed,
              foregroundColor: AppTheme.parchment,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _mergeSourceIndex = null);
              ref
                  .read(companyNotifierProvider.notifier)
                  .mergeCompanies(a.id, b.id);
            },
            child: const Text('Merge'),
          ),
        ],
      ),
    );
  }

  void _showSplitSheet(BuildContext context, CompanyOnMap co) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.parchment,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SplitSlider(
        key: ValueKey('castle_split_slider_${co.id}'),
        company: co,
        onConfirm: (splitMap) async {
          Navigator.of(ctx).pop();
          try {
            await ref
                .read(companyNotifierProvider.notifier)
                .splitCompany(co.id, splitMap);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Split failed: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companies = widget.companies;
    final mergeMode = _mergeSourceIndex != null;

    return Card(
      key: const ValueKey('castle_roster_card'),
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
                Expanded(
                  child: Text(
                    mergeMode
                        ? 'Select a company to merge with…'
                        : 'Companies here (${companies.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: mergeMode ? AppTheme.bloodRed : AppTheme.ironDark,
                    ),
                  ),
                ),
                if (mergeMode)
                  TextButton(
                    onPressed: () => setState(() => _mergeSourceIndex = null),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.stone),
                    ),
                  ),
              ],
            ),
            if (mergeMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Tap another company to merge it with the selected one.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.stone,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const Divider(),
            ...companies.asMap().entries.map((entry) {
              final index = entry.key;
              final co = entry.value;
              final isSource = index == _mergeSourceIndex;
              final isFront = !mergeMode && index == _frontIndex;
              final stationary = _isStationary(co);
              final statusLabel = stationary ? 'Garrisoned' : 'Defending';
              final ownerColor = co.ownership == Ownership.player
                  ? AppTheme.bloodRed
                  : AppTheme.midnightBlue;
              final total = co.company.totalSoldiers.value;
              final isPlayerOwned = co.ownership == Ownership.player;

              // In merge mode, grey out the source and non-stationary companies.
              final isInteractable =
                  isPlayerOwned && (stationary || mergeMode && !isSource);
              final dimmed = mergeMode && isSource;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  key: ValueKey('roster_row_${co.id}'),
                  onTap: () {
                    if (!isPlayerOwned) return;
                    if (mergeMode) {
                      if (isSource) return; // can't merge with self
                      final sourceIndex = _mergeSourceIndex!;
                      setState(() => _mergeSourceIndex = null);
                      _showMergePrompt(
                          context, companies[sourceIndex], co);
                    } else {
                      setState(() => _frontIndex = index);
                      ref
                          .read(companyNotifierProvider.notifier)
                          .selectCompany(co.id);
                      // Return to map so the player can immediately tap a
                      // destination node — the selected company marker will be
                      // pinned to slot 0 (centre) and shown highlighted.
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                  onLongPress: (isPlayerOwned && stationary && !mergeMode)
                      ? () => _showSplitSheet(context, co)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Opacity(
                    opacity: dimmed ? 0.45 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSource
                              ? AppTheme.bloodRed
                              : isFront
                                  ? const Color(0xFFFFD700)
                                  : ownerColor.withAlpha(80),
                          width: (isSource || isFront) ? 2.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isSource
                            ? AppTheme.bloodRed.withAlpha(30)
                            : isFront
                                ? const Color(0xFFFFF8DC).withAlpha(180)
                                : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$total soldiers',
                                    style: const TextStyle(
                                      color: AppTheme.ironDark,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    statusLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.stone,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSource)
                              const Icon(
                                Icons.compare_arrows,
                                color: AppTheme.bloodRed,
                                size: 18,
                              )
                            else if (isFront)
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFD700),
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Action buttons — only shown when there are ≥1 player-owned stationary companies.
            if (!mergeMode &&
                companies
                    .where((co) =>
                        co.ownership == Ownership.player && _isStationary(co))
                    .length >=
                    1) ...[
              const Divider(),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  if (companies
                          .where((co) =>
                              co.ownership == Ownership.player &&
                              _isStationary(co))
                          .length >=
                      2)
                    TextButton.icon(
                      key: const ValueKey('castle_merge_button'),
                      icon: const Icon(Icons.compare_arrows, size: 16),
                      label: const Text('Merge'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.ironDark,
                      ),
                      onPressed: () {
                        // Enter merge mode: highlight the front company as source.
                        final playerStationary = companies
                            .asMap()
                            .entries
                            .where((e) =>
                                e.value.ownership == Ownership.player &&
                                _isStationary(e.value))
                            .toList();
                        // Default source = the currently highlighted front company
                        // if it's a valid candidate, else first stationary player company.
                        final frontCo = companies[_frontIndex];
                        final frontIsCandidate =
                            frontCo.ownership == Ownership.player &&
                                _isStationary(frontCo);
                        setState(() {
                          _mergeSourceIndex = frontIsCandidate
                              ? _frontIndex
                              : playerStationary.first.key;
                        });
                      },
                    ),
                  TextButton.icon(
                    key: const ValueKey('castle_split_button'),
                    icon: const Icon(Icons.call_split, size: 16),
                    label: const Text('Split'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.ironDark,
                    ),
                    onPressed: () {
                      // Split the currently highlighted front company (if eligible).
                      final co = companies[_frontIndex];
                      if (co.ownership == Ownership.player &&
                          _isStationary(co)) {
                        _showSplitSheet(context, co);
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Read-only summary shown for enemy/neutral castles.
///
/// Displays the total number of defending soldiers. No action buttons or
/// individual company rows are shown.
class _EnemyDefenderSummary extends StatelessWidget {
  const _EnemyDefenderSummary({required this.companies});

  final List<CompanyOnMap> companies;

  @override
  Widget build(BuildContext context) {
    final totalDefenders =
        companies.fold<int>(0, (sum, co) => sum + co.company.totalSoldiers.value);

    return Card(
      key: const ValueKey('enemy_castle_defender_summary'),
      elevation: 2,
      color: AppTheme.parchment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.groups, color: AppTheme.midnightBlue, size: 22),
            const SizedBox(width: 10),
            Text(
              'Defenders: $totalDefenders soldiers',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.ironDark,
              ),
            ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.stone),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.ironDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
