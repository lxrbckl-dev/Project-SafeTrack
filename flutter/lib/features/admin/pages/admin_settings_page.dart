import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';
import '../data/admin_repository.dart';
import '../widgets/setting_section_header.dart';

/// Admin Settings page — replaces the placeholder for TASK-003.
///
/// Sections:
///   • TRIR Benchmark — numeric input, saved via PUT /api/settings/trir_benchmark
///   • Escalation Notifications — JSON-array editor (days)
///   • Factor Types — link to /admin/factor-types for full CRUD
///
/// Accessible only to Admin and Safety Manager (router already enforces this).
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final AdminRepository _repo = AdminRepository();

  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _seedingStressTest = false;

  // Controllers for editable fields
  final TextEditingController _trirController = TextEditingController();
  final TextEditingController _escalationController = TextEditingController();

  final TextEditingController _recurrenceLookbackController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _trirController.dispose();
    _escalationController.dispose();
    _recurrenceLookbackController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings = await _repo.listSettings(token);
      for (final s in settings) {
        if (s.key == 'trir_benchmark') {
          _trirController.text = s.value;
        } else if (s.key == 'escalation_days') {
          _escalationController.text = s.value;
        } else if (s.key == 'recurrence_lookback_months') {
          _recurrenceLookbackController.text = s.value;
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load settings: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _loadSettings),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveTrir() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    final value = _trirController.text.trim();
    if (double.tryParse(value) == null) {
      throw Exception('TRIR benchmark must be a valid number.');
    }

    await _repo.updateSetting(token, 'trir_benchmark', value);
  }

  Future<void> _saveEscalation() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    final value = _escalationController.text.trim();
    await _repo.updateSetting(token, 'escalation_days', value);
  }

  Future<void> _saveRecurrenceLookback() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    final value = _recurrenceLookbackController.text.trim();
    if (int.tryParse(value) == null || int.parse(value) < 1) {
      throw Exception('Lookback window must be a positive whole number.');
    }

    await _repo.updateSetting(token, 'recurrence_lookback_months', value);
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      await _saveTrir();
      await _saveEscalation();
      await _saveRecurrenceLookback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _seedStressTest() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    // Confirmation dialog.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Stress Test Data'),
        content: const Text(
          'This will generate 50 incidents, 15 investigations, '
          '20 CAPAs, and supporting data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _seedingStressTest = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/seed-stress-test');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final message = body['message'] as String? ?? 'Done';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to seed stress test data: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _seedingStressTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Page-specific action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Refresh settings',
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _loadSettings,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildErrorState()
              : _buildContent(),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: HerzogColors.errorRed),
          const SizedBox(height: 12),
          Text('Failed to load settings', style: HerzogText.body(
            color: isDark ? Colors.white : HerzogColors.richBlack,
          )),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadSettings,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------------------
          // TRIR Benchmark
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'TRIR BENCHMARK'),
          Text(
            'Target Total Recordable Incident Rate used on the dashboard.',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'TRIR benchmark value',
            child: TextFormField(
              controller: _trirController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Benchmark value',
                hintText: '3.0',
              ),
            ),
          ),

          // ----------------------------------------------------------------
          // Escalation Notifications
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'ESCALATION NOTIFICATIONS'),
          Text(
            'Comma-separated days after which an incident is escalated '
            '(JSON array, e.g. [3,7,14]).',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Escalation days JSON array',
            child: TextFormField(
              controller: _escalationController,
              decoration: const InputDecoration(
                labelText: 'Escalation days (JSON array)',
                hintText: '[3,7,14]',
              ),
            ),
          ),

          // ----------------------------------------------------------------
          // Recurrence Detection
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'RECURRENCE DETECTION'),
          Text(
            'Number of months to look back when scanning for recurring '
            'incidents.',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Lookback window in months',
            child: TextFormField(
              controller: _recurrenceLookbackController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lookback Window (months)',
                hintText: '12',
              ),
            ),
          ),

          // ----------------------------------------------------------------
          // Factor Types
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'CONTRIBUTING FACTOR TYPES'),
          Text(
            'Manage the factor types available during incident investigations.',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Manage factor types',
            child: OutlinedButton.icon(
              onPressed: () => context.push('/admin/factor-types'),
              icon: const Icon(Icons.list_alt),
              label: const Text('Manage Factor Types'),
            ),
          ),

          // ----------------------------------------------------------------
          // OSHA Log Export
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'OSHA LOG EXPORT'),
          Text(
            'Download OSHA Forms 300, 300A, and 301 as CSV files for '
            'regulatory reporting.',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Navigate to OSHA log export',
            child: OutlinedButton.icon(
              onPressed: () => context.push('/admin/osha-export'),
              icon: const Icon(Icons.download_outlined),
              label: const Text('OSHA Log Export'),
            ),
          ),

          const SizedBox(height: 32),

          // ----------------------------------------------------------------
          // Agent API Keys
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'AGENT API KEYS'),
          Text(
            'Manage API keys for external agents. Keys allow automated systems '
            'to authenticate and interact with the application.',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Navigate to agent API keys',
            child: OutlinedButton.icon(
              onPressed: () => context.push('/admin/api-keys'),
              icon: const Icon(Icons.vpn_key),
              label: const Text('Manage API Keys'),
            ),
          ),

          // ----------------------------------------------------------------
          // Agent Sessions (TASK-049)
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'AGENT SESSIONS'),
          Text(
            'Monitor live agent sessions and review agent-performed actions.',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Navigate to agent sessions',
            child: OutlinedButton.icon(
              onPressed: () => context.push('/admin/agents'),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('View Agent Sessions'),
            ),
          ),

          // ----------------------------------------------------------------
          // Stress Test Data
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'STRESS TEST DATA'),
          Text(
            'Generate bulk test data for dashboards, charts, and workflow '
            'validation. This is idempotent — running it again has no effect '
            'if data already exists.',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Generate stress test data',
            child: OutlinedButton.icon(
              onPressed: _seedingStressTest ? null : _seedStressTest,
              icon: _seedingStressTest
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science),
              label: Text(
                _seedingStressTest
                    ? 'Generating...'
                    : 'Generate Stress Test Data',
              ),
            ),
          ),

          // ----------------------------------------------------------------
          // Save Changes
          // ----------------------------------------------------------------
          Divider(color: isDark ? HerzogDarkColors.inputBorder : HerzogColors.borderGray),
          const SizedBox(height: 16),
          Semantics(
            label: 'Save all settings changes',
            button: true,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HerzogColors.navyBlue,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('SAVE CHANGES'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
