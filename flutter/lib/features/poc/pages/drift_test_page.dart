import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/connection.dart';
import '../../../core/services/sync_service.dart';

class DriftTestPage extends StatefulWidget {
  const DriftTestPage({super.key});

  @override
  State<DriftTestPage> createState() => _DriftTestPageState();
}

class _DriftTestPageState extends State<DriftTestPage> {
  late final AppDatabase _db;
  late final SyncService _syncService;
  final _controller = TextEditingController();
  List<Note> _notes = [];
  String _status = 'Initializing...';
  String _syncStatus = '';

  @override
  void initState() {
    super.initState();
    _db = constructDb();
    _syncService = SyncService(db: _db);
    _syncService.start();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await _db.getAllNotes();
      final unsynced = notes.where((n) => !n.synced).length;
      setState(() {
        _notes = notes;
        _status = 'Database ready — ${notes.length} notes ($unsynced unsynced)';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _addNote() async {
    if (_controller.text.isEmpty) return;
    await _db.addNote(_controller.text);
    _controller.clear();
    await _loadNotes();
  }

  Future<void> _triggerSync() async {
    setState(() => _syncStatus = 'Syncing...');
    final result = await _syncService.syncNow();
    setState(() => _syncStatus = result.message);
    await _loadNotes();
  }

  @override
  void dispose() {
    _controller.dispose();
    _syncService.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drift + Sync Test'),
        backgroundColor: const Color(0xFF000000),
        foregroundColor: const Color(0xFFFFD100),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Database status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _status.startsWith('Error')
                  ? const Color(0xFFF8D7DA)
                  : const Color(0xFFD4EDDA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _status,
              style: TextStyle(
                color: _status.startsWith('Error')
                    ? const Color(0xFFAB2D24)
                    : const Color(0xFF1E6B38),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Sync status + button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1ECF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _syncStatus.isEmpty ? 'Sync: idle' : _syncStatus,
                    style: const TextStyle(
                      color: Color(0xFF086670),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _triggerSync,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF086670),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Add note input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Type a note to test write...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Notes list
          Expanded(
            child: ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return ListTile(
                  title: Text(note.content),
                  subtitle: Text(
                    'ID: ${note.id} | ${note.synced ? "Synced to Firebase" : "Local only"}',
                  ),
                  trailing: Icon(
                    note.synced ? Icons.cloud_done : Icons.cloud_off,
                    color: note.synced
                        ? const Color(0xFF1E6B38)
                        : const Color(0xFF8A5700),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
