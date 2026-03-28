import 'package:shared_preferences/shared_preferences.dart';

/// Service that tracks whether the first-run onboarding tour has been shown.
///
/// Persists state via [SharedPreferences] so the tour only fires once per
/// installation.  A "Restart Tour" action in the sidebar calls [resetTour]
/// to clear the flag and allow the tour to trigger again.
///
/// ADA/WCAG: tour completion state is stored per device, so the experience
/// stays consistent regardless of authentication state.
class OnboardingService {
  static const String _prefsKey = 'onboarding_complete';

  final SharedPreferences _prefs;

  OnboardingService(this._prefs);

  /// Returns `true` when the tour has not yet been shown on this device.
  bool shouldShowTour() => _prefs.getBool(_prefsKey) != true;

  /// Marks the tour as complete so it will not be shown again automatically.
  Future<void> completeTour() => _prefs.setBool(_prefsKey, true);

  /// Clears the flag so the tour will be shown on the next shell load.
  /// Used by the "Restart Tour" action in the sidebar footer.
  Future<void> resetTour() => _prefs.remove(_prefsKey);
}
