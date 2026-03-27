import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../database/app_database.dart';
import 'api_config.dart';

/// Handles syncing local Drift data to Go API → PostgreSQL when online.
///
/// Flow:
///   1. User writes to Drift (instant, works offline)
///   2. Record is marked synced: false
///   3. SyncService detects connectivity change → online
///   4. Pulls all unsynced records from Drift
///   5. Pushes to Go API which writes to PostgreSQL
///   6. Marks each as synced: true in Drift
class SyncService {
  final AppDatabase db;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  SyncService({required this.db});

  /// Start listening for connectivity changes
  void start() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (isOnline) {
        syncNow();
      }
    });
  }

  /// Manually trigger a sync attempt
  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      return SyncResult(
        synced: 0,
        failed: 0,
        message: 'Sync already in progress',
      );
    }
    _isSyncing = true;

    try {
      final unsynced = await db.getUnsyncedNotes();
      if (unsynced.isEmpty) {
        _isSyncing = false;
        return SyncResult(synced: 0, failed: 0, message: 'Nothing to sync');
      }

      final result = await _pushToApi(unsynced);

      if (result['synced'] != null && result['synced'] > 0) {
        for (final note in unsynced) {
          await db.markSynced(note.id);
        }
      }

      _isSyncing = false;
      return SyncResult(
        synced: result['synced'] ?? 0,
        failed: result['failed'] ?? 0,
        message: 'Synced ${result['synced']}, failed ${result['failed']}',
      );
    } catch (e) {
      _isSyncing = false;
      return SyncResult(synced: 0, failed: 0, message: 'Sync error: $e');
    }
  }

  Future<Map<String, dynamic>> _pushToApi(List<Note> notes) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/sync'),
      headers: {
        'Content-Type': 'application/json',
        // TODO: Add Firebase JWT when auth is wired up
        // 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'records': notes
            .map(
              (n) => {
                'id': n.id,
                'content': n.content,
                'createdAt': n.createdAt.toIso8601String(),
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Sync failed: ${response.statusCode}');
  }

  void dispose() {
    _subscription?.cancel();
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final String message;

  SyncResult({
    required this.synced,
    required this.failed,
    required this.message,
  });
}
