/// Typed constants for offline incident sync lifecycle states.
///
/// States: pending → syncing → synced | error
///
/// Using a class with static const fields (rather than an enum) so that
/// the values can be used directly as Drift SQL string comparisons without
/// extra conversion.
class SyncStatus {
  SyncStatus._();

  /// Saved locally, not yet attempted.
  static const String pending = 'pending';

  /// Upload in-flight.
  static const String syncing = 'syncing';

  /// Successfully uploaded to server and removed from local DB.
  static const String synced = 'synced';

  /// Last upload attempt failed; will retry.
  static const String error = 'error';

  /// All valid status values.
  static const List<String> all = [pending, syncing, synced, error];
}
