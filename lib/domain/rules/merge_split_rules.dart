import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';

/// Result of a [MergeSplitRules.merge] operation.
final class MergeResult {
  /// The primary merged Company (≤ 50 soldiers).
  final Company primary;

  /// An overflow Company containing remaining soldiers when the combined total
  /// exceeded 50. Null when combined total ≤ 50.
  final Company? overflow;

  const MergeResult({required this.primary, this.overflow});
}

/// Result of a [MergeSplitRules.split] operation.
final class SplitResult {
  /// The original Company minus the split-off soldiers.
  final Company kept;

  /// The newly formed Company containing the split-off soldiers.
  final Company splitOff;

  const SplitResult({required this.kept, required this.splitOff});
}

/// Pure domain rules for merging and splitting Companies.
///
/// Zero Flutter dependencies — can be unit-tested headlessly.
abstract final class MergeSplitRules {
  /// Merge [a] and [b] into one Company.
  ///
  /// If the combined total ≤ 50, returns a single primary Company.
  ///
  /// If the combined total > 50, the primary Company contains exactly 50
  /// soldiers (filled in role order: a's roles first, then b's), and an
  /// overflow Company contains the remainder. No soldiers are lost.
  static MergeResult merge(Company a, Company b) {
    // Combine role counts.
    final combined = <UnitRole, int>{};
    for (final entry in a.composition.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }
    for (final entry in b.composition.entries) {
      combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
    }

    // Strip zero entries.
    combined.removeWhere((_, v) => v <= 0);

    final combinedTotal = combined.values.fold(0, (s, v) => s + v);

    if (combinedTotal <= 50) {
      return MergeResult(primary: Company(composition: combined));
    }

    // Split combined into primary (50) + overflow (remainder).
    // Fill primary greedily in role declaration order (UnitRole.values order).
    final primaryMap = <UnitRole, int>{};
    final overflowMap = <UnitRole, int>{};
    var remaining = 50;

    for (final role in UnitRole.values) {
      final count = combined[role] ?? 0;
      if (count == 0) continue;
      if (remaining >= count) {
        primaryMap[role] = count;
        remaining -= count;
      } else {
        if (remaining > 0) {
          primaryMap[role] = remaining;
          overflowMap[role] = count - remaining;
          remaining = 0;
        } else {
          overflowMap[role] = count;
        }
      }
    }

    return MergeResult(
      primary: Company(composition: primaryMap),
      overflow: overflowMap.isEmpty ? null : Company(composition: overflowMap),
    );
  }

  /// Split [original] into two Companies.
  ///
  /// [toSplit] specifies how many of each role to move to the new Company.
  ///
  /// Throws [ArgumentError] if:
  /// - [toSplit] is empty.
  /// - Any count in [toSplit] is zero.
  /// - Any role in [toSplit] is not present in [original].
  /// - Any role count exceeds the available count in [original].
  static SplitResult split(Company original, Map<UnitRole, int> toSplit) {
    if (toSplit.isEmpty) {
      throw ArgumentError.value(toSplit, 'toSplit', 'Split composition must not be empty.');
    }

    for (final entry in toSplit.entries) {
      if (entry.value <= 0) {
        throw ArgumentError.value(
          entry.value,
          'toSplit[${entry.key.name}]',
          'Split count must be > 0.',
        );
      }
      final available = original.composition[entry.key] ?? 0;
      if (available == 0) {
        throw ArgumentError.value(
          entry.key,
          'toSplit',
          'Role ${entry.key.name} is not in the original Company.',
        );
      }
      if (entry.value > available) {
        throw ArgumentError.value(
          entry.value,
          'toSplit[${entry.key.name}]',
          'Requested ${entry.value} but only $available available.',
        );
      }
    }

    final keptMap = Map<UnitRole, int>.from(original.composition);
    final splitMap = <UnitRole, int>{};

    for (final entry in toSplit.entries) {
      keptMap[entry.key] = keptMap[entry.key]! - entry.value;
      if (keptMap[entry.key] == 0) keptMap.remove(entry.key);
      splitMap[entry.key] = entry.value;
    }

    return SplitResult(
      kept: Company(composition: keptMap),
      splitOff: Company(composition: splitMap),
    );
  }
}
