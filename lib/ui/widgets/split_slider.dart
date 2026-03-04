import 'package:flutter/material.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

/// A widget that lets the player define how to split a [CompanyOnMap] into two.
///
/// Renders one row per role present in the Company. Each row has decrement (−)
/// and increment (+) buttons that control how many of that role go into the
/// split-off Company (Company B). A live preview shows Company A and Company B
/// totals. The "Confirm Split" button is disabled until at least 1 soldier has
/// been assigned to Company B.
///
/// [onConfirm] is called with the selected split composition when the player
/// confirms. It is the caller's responsibility to dispatch the split action to
/// [CompanyNotifier].
class SplitSlider extends StatefulWidget {
  final CompanyOnMap company;
  final void Function(Map<UnitRole, int> splitComposition) onConfirm;

  const SplitSlider({
    super.key,
    required this.company,
    required this.onConfirm,
  });

  @override
  State<SplitSlider> createState() => _SplitSliderState();
}

class _SplitSliderState extends State<SplitSlider> {
  /// How many of each role will go into Company B (the split-off Company).
  late final Map<UnitRole, int> _splitCounts;

  @override
  void initState() {
    super.initState();
    _splitCounts = {
      for (final entry in widget.company.company.composition.entries)
        if (entry.value > 0) entry.key: 0,
    };
  }

  int get _splitTotal => _splitCounts.values.fold(0, (s, v) => s + v);

  int get _originalTotal => widget.company.company.totalSoldiers.value;

  int get _keptTotal => _originalTotal - _splitTotal;

  void _increment(UnitRole role) {
    final available = widget.company.company.composition[role] ?? 0;
    final current = _splitCounts[role] ?? 0;
    if (current < available) {
      setState(() => _splitCounts[role] = current + 1);
    }
  }

  void _decrement(UnitRole role) {
    final current = _splitCounts[role] ?? 0;
    if (current > 0) {
      setState(() => _splitCounts[role] = current - 1);
    }
  }

  Map<UnitRole, int>? get _activeSplitComposition {
    final filtered = Map<UnitRole, int>.fromEntries(
      _splitCounts.entries.where((e) => e.value > 0),
    );
    return filtered.isEmpty ? null : filtered;
  }

  @override
  Widget build(BuildContext context) {
    final splitComposition = _activeSplitComposition;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Split Company',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.ironDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Role rows
          ..._splitCounts.entries.map((entry) {
            final role = entry.key;
            final splitCount = entry.value;
            final available = widget.company.company.composition[role] ?? 0;

            return Padding(
              key: ValueKey('split_row_${role.name}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_roleName(role)} (${available - splitCount} kept / $splitCount split)',
                      style: const TextStyle(color: AppTheme.ironDark),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('split_dec_${role.name}'),
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: splitCount > 0 ? () => _decrement(role) : null,
                    color: AppTheme.bloodRed,
                  ),
                  Text(
                    '$splitCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ironDark,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('split_inc_${role.name}'),
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: splitCount < available ? () => _increment(role) : null,
                    color: AppTheme.ironDark,
                  ),
                ],
              ),
            );
          }),

          const Divider(),

          // Live preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PreviewBadge(
                key: const ValueKey('split_preview_a'),
                label: 'Company A: $_keptTotal',
              ),
              _PreviewBadge(
                key: const ValueKey('split_preview_b'),
                label: 'Company B: $_splitTotal',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Confirm button
          ElevatedButton(
            key: const ValueKey('split_confirm_button'),
            onPressed: splitComposition != null
                ? () => widget.onConfirm(splitComposition)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bloodRed,
              foregroundColor: AppTheme.parchment,
              disabledBackgroundColor: AppTheme.stone,
            ),
            child: const Text('Confirm Split'),
          ),
        ],
      ),
    );
  }

  static String _roleName(UnitRole role) {
    return switch (role) {
      UnitRole.peasant => 'Peasants',
      UnitRole.warrior => 'Warriors',
      UnitRole.knight => 'Knights',
      UnitRole.archer => 'Archers',
      UnitRole.catapult => 'Catapults',
    };
  }
}

class _PreviewBadge extends StatelessWidget {
  final String label;

  const _PreviewBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.stone.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.stone),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.ironDark,
        ),
      ),
    );
  }
}
