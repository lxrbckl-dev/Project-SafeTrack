import 'package:drift/drift.dart';

/// Drift table for locally cached incidents created while offline.
///
/// Fields mirror the incident form so that all user-entered data is preserved.
/// Photos are stored as file paths (not blobs) to keep the SQLite DB lean.
/// The [syncStatus] field tracks the lifecycle: pending → syncing → synced/error.
class OfflineIncidents extends Table {
  /// Local auto-increment ID (not the server ID).
  IntColumn get id => integer().autoIncrement()();

  // -- Basic Info --
  TextColumn get type => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get location => text().withDefault(const Constant(''))();
  RealColumn get latitude => real().withDefault(const Constant(0.0))();
  RealColumn get longitude => real().withDefault(const Constant(0.0))();
  TextColumn get division => text().withDefault(const Constant(''))();
  TextColumn get projectJobSite => text().withDefault(const Constant(''))();

  // -- Description --
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get immediateActions => text().withDefault(const Constant(''))();

  // -- Classification --
  TextColumn get severity => text().withDefault(const Constant(''))();
  TextColumn get potentialSeverity => text().withDefault(const Constant(''))();
  TextColumn get shift => text().withDefault(const Constant(''))();
  TextColumn get weather => text().withDefault(const Constant(''))();

  // -- Railroad --
  BoolColumn get isRailroadProperty =>
      boolean().withDefault(const Constant(false))();
  TextColumn get railroadClient => text().withDefault(const Constant(''))();
  BoolColumn get railroadNotified =>
      boolean().withDefault(const Constant(false))();
  TextColumn get railroadNotificationMethod =>
      text().withDefault(const Constant(''))();

  // -- Injured person (JSON-encoded list) --
  TextColumn get injuredPersonsJson =>
      text().withDefault(const Constant('[]'))();

  // -- Photo file paths (JSON-encoded list of strings) --
  TextColumn get photoPathsJson => text().withDefault(const Constant('[]'))();

  // -- Meta --
  BoolColumn get isDraft => boolean().withDefault(const Constant(true))();
  TextColumn get reporterId => text().withDefault(const Constant(''))();

  /// Sync lifecycle: pending, syncing, synced, error
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Error message from last failed sync attempt, if any.
  TextColumn get syncError => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
