import 'package:flutter/foundation.dart';

/// Service that holds pending form-fill data dispatched by the AI agent.
///
/// When the AI returns a "fill" or "navigate_and_fill" action, the field map
/// is stored here. Form pages check this service on init — if there is pending
/// data, they auto-populate their controllers and then clear the pending data.
///
/// Registered as a [ChangeNotifier] in [MultiProvider] in `main.dart`.
class FormFillService extends ChangeNotifier {
  Map<String, String>? _pendingFields;

  /// The pending field map, or null if no fill is queued.
  Map<String, String>? get pendingFields => _pendingFields;

  /// Whether there is pending data waiting to be consumed by a form.
  bool get hasPendingData =>
      _pendingFields != null && _pendingFields!.isNotEmpty;

  /// Queue field values for auto-fill. Called by the action dispatcher.
  void setPendingFields(Map<String, String> fields) {
    _pendingFields = Map<String, String>.from(fields);
    notifyListeners();
  }

  /// Consume and clear the pending data. Called by form pages after filling.
  /// Returns the field map (may be null if nothing was pending).
  Map<String, String>? consumePendingFields() {
    final fields = _pendingFields;
    _pendingFields = null;
    // No need to notifyListeners here — the form has already consumed the data.
    return fields;
  }

  /// Clear pending data without consuming (e.g., on navigation away).
  void clear() {
    _pendingFields = null;
  }
}
