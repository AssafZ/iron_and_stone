/// Records the intent of a company to perform a proximity-based merge with a
/// specific target company.
///
/// When set on a [CompanyOnMap], the initiating company will auto-march toward
/// the target's current road position each tick. The merge executes when the
/// initiator arrives at the target's position. The intent is cancelled if:
/// - The road distance exceeds [kProximityMergeThreshold] at any tick.
/// - Either company enters an active battle.
/// - The target company no longer exists (was merged or destroyed).
///
/// Pure Dart — zero Flutter dependencies.
final class ProximityMergeIntent {
  /// ID of the target [CompanyOnMap] the initiator will march toward.
  final String targetCompanyId;

  ProximityMergeIntent({required this.targetCompanyId}) {
    if (targetCompanyId.isEmpty) {
      throw ArgumentError(
        'ProximityMergeIntent.targetCompanyId must not be empty.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProximityMergeIntent &&
          targetCompanyId == other.targetCompanyId;

  @override
  int get hashCode => targetCompanyId.hashCode;

  @override
  String toString() => 'ProximityMergeIntent(target=$targetCompanyId)';
}
