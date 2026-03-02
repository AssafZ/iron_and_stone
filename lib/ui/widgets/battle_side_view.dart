import 'package:flutter/material.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';

/// Side-view widget showing a single side of a battle.
///
/// Displays melee units at front (left) and ranged / Peasant units at rear (right).
/// HP bars are shown beneath each unit group with [Key('hp_bar')].
final class BattleSideView extends StatelessWidget {
  final List<Company> companies;
  final String label;

  const BattleSideView({
    super.key,
    required this.companies,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final melee = <MapEntry<UnitRole, int>>[];
    final ranged = <MapEntry<UnitRole, int>>[];

    for (final company in companies) {
      for (final entry in company.composition.entries) {
        if (entry.value <= 0) continue;
        if (entry.key.range == 1) {
          melee.add(entry);
        } else {
          ranged.add(entry);
        }
      }
    }

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade900,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Melee front
                Expanded(
                  child: _UnitGroup(
                    sectionLabel: 'Melee',
                    entries: melee,
                  ),
                ),
                const SizedBox(width: 8),
                // Ranged rear
                Expanded(
                  child: _UnitGroup(
                    sectionLabel: 'Ranged',
                    entries: ranged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitGroup extends StatelessWidget {
  final String sectionLabel;
  final List<MapEntry<UnitRole, int>> entries;

  const _UnitGroup({required this.sectionLabel, required this.entries});

  @override
  Widget build(BuildContext context) {
    final total = entries.fold(0, (sum, e) => sum + e.value);
    final maxHp = entries.fold(0, (sum, e) => sum + e.value * e.key.hp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionLabel,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        if (entries.isEmpty)
          const Text(
            '—',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          )
        else ...[
          Text(
            '$total soldiers',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 4),
          // HP bar
          SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              key: const Key('hp_bar'),
              value: maxHp > 0 ? 1.0 : 0.0,
              backgroundColor: Colors.red.shade900,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
          ),
        ],
      ],
    );
  }
}
