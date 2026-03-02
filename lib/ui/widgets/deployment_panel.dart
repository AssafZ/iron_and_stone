import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/state/company_notifier.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

/// Deployment panel: lets the player select a role composition (up to 50
/// soldiers total) and deploy a Company from a castle garrison.
///
/// Contains no game-rule logic — delegates to [CompanyNotifier.deployCompany].
class DeploymentPanel extends ConsumerStatefulWidget {
  const DeploymentPanel({
    super.key,
    required this.castleId,
    required this.castleNode,
  });

  final String castleId;
  final CastleNode castleNode;

  @override
  ConsumerState<DeploymentPanel> createState() => _DeploymentPanelState();
}

class _DeploymentPanelState extends ConsumerState<DeploymentPanel> {
  /// The composition selected by the player; roles are keyed by [UnitRole].
  final Map<UnitRole, int> _composition = {
    for (final role in UnitRole.values) role: 0,
  };

  int get _total => _composition.values.fold(0, (s, v) => s + v);
  bool get _isValid => _total > 0 && _total <= 50;

  void _increment(UnitRole role, int available) {
    final current = _composition[role] ?? 0;
    if (current >= available) return; // can't deploy more than available
    if (_total >= 50) return; // 50-soldier cap
    setState(() => _composition[role] = current + 1);
  }

  void _decrement(UnitRole role) {
    final current = _composition[role] ?? 0;
    if (current <= 0) return;
    setState(() => _composition[role] = current - 1);
  }

  Future<void> _deploy(BuildContext context) async {
    final matchState = ref.read(matchNotifierProvider).valueOrNull;
    if (matchState == null) return;

    try {
      await ref.read(companyNotifierProvider.notifier).deployCompany(
            castleId: widget.castleId,
            castleNode: widget.castleNode,
            composition: Map.from(_composition),
            map: matchState.match.map,
          );
      // Reset composition.
      setState(() {
        for (final role in UnitRole.values) {
          _composition[role] = 0;
        }
      });
      if (context.mounted) {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deploy failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchNotifierProvider).valueOrNull;
    final castle = matchState?.castles
        .where((c) => c.id == widget.castleId)
        .firstOrNull;

    return RepaintBoundary(
      key: const ValueKey('deployment_panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Deploy Company',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.ironDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Running total badge
            _TotalBadge(total: _total),
            const SizedBox(height: 12),
            // Per-role steppers
            ...UnitRole.values.map((role) {
              final available = castle?.garrison[role] ?? 0;
              final selected = _composition[role] ?? 0;
              return _RoleStepper(
                role: role,
                available: available,
                selected: selected,
                onIncrement: () => _increment(role, available),
                onDecrement: () => _decrement(role),
              );
            }),
            const SizedBox(height: 16),
            // Deploy button
            ElevatedButton(
              key: const ValueKey('deploy_button'),
              onPressed: (_isValid && context.mounted)
                  ? () => _deploy(context)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bloodRed,
                foregroundColor: AppTheme.parchment,
                disabledBackgroundColor: AppTheme.stone,
              ),
              child: Text(_isValid
                  ? 'Deploy $_total Soldiers'
                  : (_total == 0 ? 'Select soldiers to deploy' : 'Cap reached (max 50)')),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets (private)
// ---------------------------------------------------------------------------

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final over = total > 50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: over ? AppTheme.bloodRed.withAlpha(30) : AppTheme.gold.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: over ? AppTheme.bloodRed : AppTheme.gold,
        ),
      ),
      child: Text(
        'Total: $total / 50',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: over ? AppTheme.bloodRed : AppTheme.ironDark,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _RoleStepper extends StatelessWidget {
  const _RoleStepper({
    required this.role,
    required this.available,
    required this.selected,
    required this.onIncrement,
    required this.onDecrement,
  });

  final UnitRole role;
  final int available;
  final int selected;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  String get _roleName {
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

  String get _roleKey => role.name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roleName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ironDark,
                  ),
                ),
                Text(
                  'Available: $available',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.stone,
                  ),
                ),
              ],
            ),
          ),
          // Decrement
          IconButton(
            key: ValueKey('stepper_decrement_$_roleKey'),
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: selected > 0 ? onDecrement : null,
            color: AppTheme.ironDark,
            iconSize: 20,
          ),
          // Count display
          SizedBox(
            width: 36,
            child: Text(
              '$selected',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.ironDark,
              ),
            ),
          ),
          // Increment
          IconButton(
            key: ValueKey('stepper_increment_$_roleKey'),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: (selected < available) ? onIncrement : null,
            color: AppTheme.bloodRed,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
