import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist the dark-mode preference.
const _kDarkModeKey = 'safetrack_dark_mode';

/// Manages the app-wide light/dark theme preference.
///
/// Responsibilities (Single Responsibility):
/// - Expose [isDarkMode] bool.
/// - Provide [toggle] to flip the preference.
/// - Persist the preference to [SharedPreferences] under [_kDarkModeKey].
/// - Load the persisted preference on initialisation via [loadPreference].
///
/// Usage:
/// ```dart
/// // Register in MultiProvider
/// ChangeNotifierProvider(create: (_) => ThemeService()..loadPreference()),
///
/// // Consume
/// context.watch<ThemeService>().isDarkMode
/// context.read<ThemeService>().toggle()
/// ```
class ThemeService extends ChangeNotifier {
  bool _isDarkMode = false;

  /// Whether dark mode is currently active.
  bool get isDarkMode => _isDarkMode;

  /// Toggles between light and dark mode and persists the new preference.
  Future<void> toggle() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _persist();
  }

  /// Loads the persisted preference from [SharedPreferences].
  ///
  /// Call once after construction (e.g. in the Provider `create` callback).
  Future<void> loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_kDarkModeKey) ?? false;
      notifyListeners();
    } catch (_) {
      // If SharedPreferences is unavailable (e.g. first run on web), default
      // to light mode — not a hard error.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDarkModeKey, _isDarkMode);
    } catch (_) {
      // Persistence failure is non-fatal — the in-memory value remains correct
      // for the current session.
    }
  }
}
