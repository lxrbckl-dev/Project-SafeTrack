import 'package:drift/drift.dart';

part 'app_database.g.dart';

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  Future<List<Note>> getAllNotes() => select(notes).get();

  Future<int> addNote(String content) =>
      into(notes).insert(NotesCompanion.insert(content: content));

  Future<int> markSynced(int id) =>
      (update(notes)..where((n) => n.id.equals(id)))
          .write(const NotesCompanion(synced: Value(true)));

  Future<List<Note>> getUnsyncedNotes() =>
      (select(notes)..where((n) => n.synced.equals(false))).get();
}
