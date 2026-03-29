import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/services/api_config.dart';
import '../widgets/setting_section_header.dart';
import '../../auth/data/auth_service.dart';
import '../../incidents/data/incident_repository.dart';
import 'osha_download_stub.dart'
    if (dart.library.html) 'osha_download_web.dart';

/// OSHA Export page — Safety Manager and Admin download OSHA logs as CSV.
///
/// Route: /admin/osha-export
///
/// Web: browser download via `<a download>` anchor click.
/// Mobile/Desktop: CSV shown in a selectable dialog with copy-to-clipboard.
class OshaExportPage extends StatefulWidget {
  const OshaExportPage({super.key});

  @override
  State<OshaExportPage> createState() => _OshaExportPageState();
}

class _OshaExportPageState extends State<OshaExportPage> {
  late IncidentRepository _incidentRepo;
  bool _repoInitialized = false;

  int _selectedYear = DateTime.now().year;
  int? _selectedIncidentId;

  bool _loading300 = false;
  bool _loading300A = false;
  bool _loading301 = false;
  bool _loadingIncidents = true;

  List<Incident> _oshaIncidents = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInitialized) {
      _repoInitialized = true;
      _incidentRepo = IncidentRepository(context.read<AuthService>());
      _loadOshaIncidents();
    }
  }

  Future<void> _loadOshaIncidents() async {
    if (!mounted) return;
    setState(() => _loadingIncidents = true);
    try {
      // Fetch up to 100 incidents to cover most deployments.
      final result = await _incidentRepo.listIncidents(perPage: 100);
      final recordable = result.data
          .where((i) => i.isOshaRecordable == true)
          .toList();
      if (mounted) {
        setState(() {
          _oshaIncidents = recordable;
          if (recordable.isNotEmpty && _selectedIncidentId == null) {
            _selectedIncidentId = recordable.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load incidents: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadOshaIncidents,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingIncidents = false);
    }
  }

  /// Fetches a CSV from [url] and delivers it to the user.
  Future<void> _downloadCsv({
    required String url,
    required String filename,
    required String token,
    required ValueSetter<bool> setLoading,
  }) async {
    setLoading(true);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      switch (response.statusCode) {
        case 403:
          throw Exception('Forbidden: Safety Manager or Admin role required');
        case 400:
          throw Exception('Incident is not OSHA recordable');
        case 404:
          throw Exception('Incident not found');
        default:
          if (response.statusCode != 200) {
            throw Exception('Download failed (HTTP ${response.statusCode})');
          }
      }

      final bytes = response.bodyBytes;
      if (kIsWeb) {
        // Delegate to platform-specific implementation (osha_download_web.dart).
        downloadCsvOnWeb(bytes, filename);
      } else {
        if (mounted) _showCsvDialog(utf8.decode(bytes), filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _downloadCsv(
                url: url,
                filename: filename,
                token: token,
                setLoading: setLoading,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setLoading(false);
    }
  }

  /// Shows CSV content in a scrollable, selectable dialog for non-web targets.
  void _showCsvDialog(String csv, String filename) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(filename, style: HerzogText.heading(fontSize: 16)),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Semantics(
            label: 'CSV export content for $filename',
            child: SingleChildScrollView(
              child: SelectableText(
                csv,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard')),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _download300() => _downloadCsv(
    url: '${ApiConfig.baseUrl}/api/osha/300?year=$_selectedYear',
    filename: 'osha_300_$_selectedYear.csv',
    token: context.read<AuthService>().token ?? '',
    setLoading: (v) => setState(() => _loading300 = v),
  );

  Future<void> _download300A() => _downloadCsv(
    url: '${ApiConfig.baseUrl}/api/osha/300a?year=$_selectedYear',
    filename: 'osha_300a_$_selectedYear.csv',
    token: context.read<AuthService>().token ?? '',
    setLoading: (v) => setState(() => _loading300A = v),
  );

  Future<void> _download301() async {
    if (_selectedIncidentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an OSHA-recordable incident.'),
        ),
      );
      return;
    }
    await _downloadCsv(
      url: '${ApiConfig.baseUrl}/api/osha/301/$_selectedIncidentId',
      filename: 'osha_301_incident_$_selectedIncidentId.csv',
      token: context.read<AuthService>().token ?? '',
      setLoading: (v) => setState(() => _loading301 = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - i);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OSHA LOG EXPORT'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Year selector ------------------------------------------------
            const SettingSectionHeader(title: 'REPORTING YEAR'),
            Text(
              'Select the calendar year for OSHA 300 and 300A exports.',
              style: HerzogText.body(
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Select reporting year',
              child: DropdownButtonFormField<int>(
                initialValue: _selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (y) {
                  if (y != null) setState(() => _selectedYear = y);
                },
              ),
            ),

            const SizedBox(height: 32),

            // OSHA Form 300 ------------------------------------------------
            const SettingSectionHeader(title: 'OSHA FORM 300 — LOG'),
            Text(
              'Log of Work-Related Injuries and Illnesses. '
              'One row per injured person for each OSHA-recordable incident '
              'in $_selectedYear.',
              style: HerzogText.body(
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Download OSHA Form 300 for $_selectedYear',
              child: ElevatedButton.icon(
                onPressed: _loading300 ? null : _download300,
                icon: _loading300
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HerzogColors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text('Download OSHA 300 ($_selectedYear)'),
              ),
            ),

            const SizedBox(height: 32),

            // OSHA Form 300A -----------------------------------------------
            const SettingSectionHeader(title: 'OSHA FORM 300A — SUMMARY'),
            Text(
              'Annual Summary of Work-Related Injuries and Illnesses. '
              'Aggregated totals for $_selectedYear.',
              style: HerzogText.body(
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Download OSHA Form 300A summary for $_selectedYear',
              child: ElevatedButton.icon(
                onPressed: _loading300A ? null : _download300A,
                icon: _loading300A
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HerzogColors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text('Download OSHA 300A ($_selectedYear)'),
              ),
            ),

            const SizedBox(height: 32),

            // OSHA Form 301 ------------------------------------------------
            const SettingSectionHeader(
              title: 'OSHA FORM 301 — INCIDENT REPORT',
            ),
            Text(
              'Individual Injury and Illness Incident Report. '
              'Select an OSHA-recordable incident to generate its Form 301.',
              style: HerzogText.body(
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingIncidents)
              const Center(child: CircularProgressIndicator())
            else if (_oshaIncidents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No OSHA-recordable incidents found. '
                  'Mark an incident as OSHA recordable to generate a Form 301.',
                  style: HerzogText.body().copyWith(
                    color: isDark ? Colors.white : HerzogColors.midGray,
                  ),
                ),
              )
            else ...[
              Semantics(
                label: 'Select OSHA-recordable incident for Form 301',
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedIncidentId,
                  decoration: const InputDecoration(
                    labelText: 'Select Incident',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: _oshaIncidents
                      .map(
                        (inc) => DropdownMenuItem(
                          value: inc.id,
                          child: Text(
                            '#${inc.id} — ${inc.type}'
                            '${inc.date != null ? ' (${_fmtDate(inc.date!)})' : ''}'
                            ' — ${inc.location}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null) setState(() => _selectedIncidentId = id);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Download OSHA Form 301 for selected incident',
                child: ElevatedButton.icon(
                  onPressed: _loading301 ? null : _download301,
                  icon: _loading301
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HerzogColors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: const Text('Download OSHA 301'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.year}';
}
