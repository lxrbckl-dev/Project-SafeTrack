import 'package:drift_flutter/drift_flutter.dart';
import 'app_database.dart';

AppDatabase constructDb() {
  return AppDatabase(
    driftDatabase(
      name: 'the_march_project',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );
}
