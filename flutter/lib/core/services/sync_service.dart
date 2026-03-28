import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../database/app_database.dart';
import 'api_config.dart';
import 'sync_status.dart';

/// Handles syncing local Drift data to Go API when online.
///
/// This is a [ChangeNotifier] so that UI widgets can reactively rebuild when
/// connectivity state or pending-sync counts change.
///
/// Flow:
///   1. User writes to Drift (instant, works offline)
///   2. Record is marked syncStatus: 'pending'
///   3. SyncService detects connectivity change → online
///   4. Pulls all pending offline incidents from Drift
///   5. POSTs each to the Go API (/api/incidents)
///   6. On success: marks as synced, removes from local DB
///   7. On failure: marks as error, retries on next connectivity change
///   8. Photos: uploads after the incident is synced
///
/// Conflict resolution: server wins (last-write-wins).
class SyncService extends ChangeNotifier {
  final AppDatabase db;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;
  bool _isOnline = true;
  int _pendingCount = 0;
  StreamSubscription<int>? _pendingCountSub;

  /// Auth token for API calls. Set by ProxyProvider from AuthService.
  String? authToken;

  SyncService({required this.db});

  /// Whether the device currently has network connectivity.
  bool get isOnline => _isOnline;

  /// Number of incidents waiting to sync.
  int get pendingCount => _pendingCount;

  /// Whether a sync operation is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Start listening for connectivity changes and pending count updates.
  void start() {
    // Reset any rows stuck in 'syncing' from a previous app session that
    // was killed mid-sync, so they will be retried in this session.
    db.resetStuckSyncingRows();

    // Listen for connectivity changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
      if (online) {
        syncIncidents();
      }
    });

    // Check initial connectivity
    Connectivity().checkConnectivity().then((results) {
      final online =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });

    // Watch pending count from Drift for reactive badge updates.
    _pendingCountSub = db.watchPendingCount().listen((count) {
      if (count != _pendingCount) {
        _pendingCount = count;
        notifyListeners();
      }
    });
  }

  /// Save an incident to the local Drift DB for offline storage.
  ///
  /// [incidentJson] is the serialized incident data (same shape as the API).
  /// [photoPaths] is a list of local file paths for attached photos.
  Future<int> saveIncidentOffline({
    required Map<String, dynamic> incidentJson,
    List<String> photoPaths = const [],
  }) async {
    final entry = OfflineIncidentsCompanion(
      type: Value(incidentJson['type'] as String? ?? ''),
      date: Value(
        incidentJson['date'] != null
            ? DateTime.parse(incidentJson['date'] as String)
            : null,
      ),
      location: Value(incidentJson['location'] as String? ?? ''),
      latitude: Value((incidentJson['latitude'] as num?)?.toDouble() ?? 0.0),
      longitude: Value((incidentJson['longitude'] as num?)?.toDouble() ?? 0.0),
      division: Value(incidentJson['division'] as String? ?? ''),
      projectJobSite: Value(incidentJson['projectJobSite'] as String? ?? ''),
      description: Value(incidentJson['description'] as String? ?? ''),
      immediateActions: Value(
        incidentJson['immediateActions'] as String? ?? '',
      ),
      severity: Value(incidentJson['severity'] as String? ?? ''),
      potentialSeverity: Value(
        incidentJson['potentialSeverity'] as String? ?? '',
      ),
      shift: Value(incidentJson['shift'] as String? ?? ''),
      weather: Value(incidentJson['weather'] as String? ?? ''),
      isRailroadProperty: Value(
        incidentJson['isRailroadProperty'] as bool? ?? false,
      ),
      railroadClient: Value(incidentJson['railroadClient'] as String? ?? ''),
      railroadNotified: Value(
        incidentJson['railroadNotified'] as bool? ?? false,
      ),
      railroadNotificationMethod: Value(
        incidentJson['railroadNotificationMethod'] as String? ?? '',
      ),
      injuredPersonsJson: Value(
        jsonEncode(incidentJson['injuredPersons'] ?? []),
      ),
      photoPathsJson: Value(jsonEncode(photoPaths)),
      isDraft: Value(incidentJson['isDraft'] as bool? ?? true),
      reporterId: Value(incidentJson['reporterId'] as String? ?? ''),
      syncStatus: const Value(SyncStatus.pending),
    );

    final id = await db.insertOfflineIncident(entry);
    notifyListeners();
    return id;
  }

  /// Sync all pending offline incidents to the API.
  Future<SyncResult> syncIncidents() async {
    if (_isSyncing || !_isOnline) {
      return SyncResult(
        synced: 0,
        failed: 0,
        message: _isSyncing ? 'Sync already in progress' : 'Offline',
      );
    }
    _isSyncing = true;
    notifyListeners();

    int synced = 0;
    int failed = 0;

    try {
      final pending = await db.getPendingIncidents();
      if (pending.isEmpty) {
        _isSyncing = false;
        notifyListeners();
        return SyncResult(synced: 0, failed: 0, message: 'Nothing to sync');
      }

      for (final incident in pending) {
        try {
          // Mark as syncing
          await db.updateSyncStatus(incident.id, SyncStatus.syncing);

          // Build the API payload
          final payload = _buildApiPayload(incident);

          // POST to the incidents API
          final response = await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/incidents'),
            headers: _headers,
            body: jsonEncode(payload),
          );

          if (response.statusCode == 201 || response.statusCode == 200) {
            final serverIncident =
                jsonDecode(response.body) as Map<String, dynamic>;
            final serverId = serverIncident['id'] as int?;

            // Upload photos if the incident was created successfully
            if (serverId != null) {
              await _uploadPhotos(serverId, incident);
            }

            // Mark as synced and remove from local DB
            await db.updateSyncStatus(incident.id, SyncStatus.synced);
            await db.deleteOfflineIncident(incident.id);
            synced++;
          } else if (response.statusCode == 409) {
            // Conflict: server wins (last-write-wins). Discard local copy.
            await db.updateSyncStatus(incident.id, SyncStatus.synced);
            await db.deleteOfflineIncident(incident.id);
            synced++;
          } else {
            await db.updateSyncStatus(
              incident.id,
              SyncStatus.error,
              error: 'HTTP ${response.statusCode}: ${response.body}',
            );
            failed++;
          }
        } catch (e) {
          await db.updateSyncStatus(
            incident.id,
            SyncStatus.error,
            error: e.toString(),
          );
          failed++;
        }
      }
    } catch (e) {
      debugPrint('SyncService.syncIncidents error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }

    return SyncResult(
      synced: synced,
      failed: failed,
      message: 'Synced $synced, failed $failed',
    );
  }

  /// Build the JSON payload matching the Go API /api/incidents endpoint.
  Map<String, dynamic> _buildApiPayload(OfflineIncident incident) {
    final payload = <String, dynamic>{
      'type': incident.type,
      'location': incident.location,
      'latitude': incident.latitude,
      'longitude': incident.longitude,
      'division': incident.division,
      'projectJobSite': incident.projectJobSite,
      'description': incident.description,
      'immediateActions': incident.immediateActions,
      'severity': incident.severity,
      'potentialSeverity': incident.potentialSeverity,
      'shift': incident.shift,
      'weather': incident.weather,
      'isDraft': incident.isDraft,
      'isRailroadProperty': incident.isRailroadProperty,
      'railroadClient': incident.railroadClient,
      'railroadNotified': incident.railroadNotified,
      'railroadNotificationMethod': incident.railroadNotificationMethod,
    };

    if (incident.date != null) {
      payload['date'] = incident.date!.toUtc().toIso8601String();
    }

    // Decode injured persons JSON
    try {
      final injuredPersons =
          jsonDecode(incident.injuredPersonsJson) as List<dynamic>;
      if (injuredPersons.isNotEmpty) {
        payload['injuredPersons'] = injuredPersons;
      }
    } catch (_) {
      // Ignore JSON parse errors for injured persons
    }

    return payload;
  }

  /// Upload queued photos for a synced incident.
  Future<void> _uploadPhotos(int serverId, OfflineIncident incident) async {
    try {
      final photoPaths = jsonDecode(incident.photoPathsJson) as List<dynamic>;
      for (final path in photoPaths) {
        try {
          final file = XFile(path as String);
          final uri = Uri.parse(
            '${ApiConfig.baseUrl}/api/incidents/$serverId/photos',
          );
          final request = http.MultipartRequest('POST', uri);
          if (authToken != null) {
            request.headers['Authorization'] = 'Bearer $authToken';
          }
          final bytes = await file.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: file.name),
          );
          final streamedResponse = await request.send();
          if (streamedResponse.statusCode != 201) {
            debugPrint(
              'Photo upload failed for incident $serverId: '
              '${streamedResponse.statusCode}',
            );
          }
        } catch (e) {
          debugPrint('Photo upload error: $e');
        }
      }
    } catch (_) {
      // Ignore JSON parse errors for photo paths
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  // -- Legacy notes sync (preserved for backward compatibility) --

  /// Manually trigger a notes sync attempt (legacy).
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

      final result = await _pushNotesToApi(unsynced);

      if (result['synced'] != null && (result['synced'] as int) > 0) {
        for (final note in unsynced) {
          await db.markSynced(note.id);
        }
      }

      _isSyncing = false;
      return SyncResult(
        synced: result['synced'] as int? ?? 0,
        failed: result['failed'] as int? ?? 0,
        message: 'Synced ${result['synced']}, failed ${result['failed']}',
      );
    } catch (e) {
      _isSyncing = false;
      return SyncResult(synced: 0, failed: 0, message: 'Sync error: $e');
    }
  }

  Future<Map<String, dynamic>> _pushNotesToApi(List<Note> notes) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/sync'),
      headers: {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
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
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Sync failed: ${response.statusCode}');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pendingCountSub?.cancel();
    super.dispose();
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
