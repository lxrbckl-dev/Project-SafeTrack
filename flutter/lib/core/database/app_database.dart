import 'package:drift/drift.dart';

import '../services/sync_status.dart';
import 'offline_incidents.dart';

part 'app_database.g.dart';

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Notes, OfflineIncidents])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(offlineIncidents);
      }
    },
  );

  // -- Notes queries (existing) --

  Future<List<Note>> getAllNotes() => select(notes).get();

  Future<int> addNote(String content) =>
      into(notes).insert(NotesCompanion.insert(content: content));

  Future<int> markSynced(int id) =>
      (update(notes)..where((n) => n.id.equals(id))).write(
        const NotesCompanion(synced: Value(true)),
      );

  Future<List<Note>> getUnsyncedNotes() =>
      (select(notes)..where((n) => n.synced.equals(false))).get();

  // -- Offline Incidents queries --

  /// Insert a new offline incident. Returns the auto-generated local ID.
  Future<int> insertOfflineIncident(OfflineIncidentsCompanion entry) =>
      into(offlineIncidents).insert(entry);

  /// Get all offline incidents that need syncing (pending or error).
  Future<List<OfflineIncident>> getPendingIncidents() =>
      (select(offlineIncidents)..where(
            (t) =>
                t.syncStatus.isIn(const [SyncStatus.pending, SyncStatus.error]),
          ))
          .get();

  /// Get all offline incidents for display (any status except synced).
  Future<List<OfflineIncident>> getUnsyncedIncidents() => (select(
    offlineIncidents,
  )..where((t) => t.syncStatus.isNotValue(SyncStatus.synced))).get();

  /// Reset any rows that are stuck in 'syncing' (app was killed mid-sync)
  /// back to 'pending' so they will be retried on next sync.
  Future<int> resetStuckSyncingRows() =>
      (update(
        offlineIncidents,
      )..where((t) => t.syncStatus.equals(SyncStatus.syncing))).write(
        OfflineIncidentsCompanion(
          syncStatus: const Value(SyncStatus.pending),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Get all offline incidents regardless of status.
  Future<List<OfflineIncident>> getAllOfflineIncidents() =>
      select(offlineIncidents).get();

  /// Update the sync status of an offline incident.
  Future<int> updateSyncStatus(int id, String status, {String error = ''}) =>
      (update(offlineIncidents)..where((t) => t.id.equals(id))).write(
        OfflineIncidentsCompanion(
          syncStatus: Value(status),
          syncError: Value(error),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Remove a synced incident from local storage.
  Future<int> deleteOfflineIncident(int id) =>
      (delete(offlineIncidents)..where((t) => t.id.equals(id))).go();

  /// Watch pending incident count for reactive UI updates.
  Stream<int> watchPendingCount() {
    final query = selectOnly(offlineIncidents)
      ..where(
        offlineIncidents.syncStatus.isIn(const [
          SyncStatus.pending,
          SyncStatus.error,
        ]),
      )
      ..addColumns([offlineIncidents.id.count()]);
    return query.watchSingle().map(
      (row) => row.read(offlineIncidents.id.count()) ?? 0,
    );
  }
}
