import 'package:shared_preferences/shared_preferences.dart';

/// Repository for user-facing app settings, backed by [SharedPreferences].
///
/// Persists:
/// - [soundEnabled]: whether game audio is on (default: true).
/// - [brightnessLevel]: display brightness preference 0.0–1.0 (default: 0.7).
class SettingsRepository {
  static const _keySoundEnabled = 'settings.soundEnabled';
  static const _keyBrightnessLevel = 'settings.brightnessLevel';

  final SharedPreferences _prefs;

  const SettingsRepository(this._prefs);

  // ---------------------------------------------------------------------------
  // Sound
  // ---------------------------------------------------------------------------

  /// Returns whether game audio is enabled. Defaults to `true`.
  bool get soundEnabled => _prefs.getBool(_keySoundEnabled) ?? true;

  /// Persists the [soundEnabled] preference.
  Future<void> setSoundEnabled(bool value) =>
      _prefs.setBool(_keySoundEnabled, value);

  // ---------------------------------------------------------------------------
  // Brightness
  // ---------------------------------------------------------------------------

  /// Returns the display brightness level ∈ [0.0, 1.0]. Defaults to `0.7`.
  double get brightnessLevel => _prefs.getDouble(_keyBrightnessLevel) ?? 0.7;

  /// Persists the [brightnessLevel] preference (clamped to [0.0, 1.0]).
  Future<void> setBrightnessLevel(double value) =>
      _prefs.setDouble(_keyBrightnessLevel, value.clamp(0.0, 1.0));

  // ---------------------------------------------------------------------------
  // First-run hint
  // ---------------------------------------------------------------------------

  static const _keyHintShown = 'settings.firstRunHintShown';

  /// Returns `true` if the first-run deployment hint has been shown.
  bool get firstRunHintShown => _prefs.getBool(_keyHintShown) ?? false;

  /// Marks the first-run hint as shown so it is not displayed again.
  Future<void> markFirstRunHintShown() => _prefs.setBool(_keyHintShown, true);
}
