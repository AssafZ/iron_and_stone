/// A validated soldier count in the range [0, 50].
///
/// Throws [ArgumentError] if the provided value is outside [0, 50].
final class SoldierCount {
  static const int min = 0;
  static const int max = 50;

  final int value;

  SoldierCount(this.value) {
    if (value < min || value > max) {
      throw ArgumentError.value(
        value,
        'value',
        'SoldierCount must be in range [$min, $max], got $value.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoldierCount && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SoldierCount($value)';
}
