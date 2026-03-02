/// Ownership of a map node (castle) or Company.
///
/// Serializes to/from a plain string for persistence.
enum Ownership {
  player,
  ai,
  neutral;

  /// Deserializes from a string produced by [name].
  ///
  /// Throws [ArgumentError] for unrecognised values.
  static Ownership fromString(String value) {
    return switch (value) {
      'player' => Ownership.player,
      'ai' => Ownership.ai,
      'neutral' => Ownership.neutral,
      _ => throw ArgumentError.value(
          value,
          'value',
          'Unknown Ownership value: "$value". Valid values: player, ai, neutral.',
        ),
    };
  }
}
