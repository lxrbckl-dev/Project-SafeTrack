import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
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

  // Controllers for editable fields
  final TextEditingController _trirController = TextEditingController();
  final TextEditingController _escalationController = TextEditingController();

  final TextEditingController _recurrenceLookbackController =
      TextEditingController();

  bool _savingTrir = false;
  bool _savingEscalation = false;
  bool _savingRecurrenceLookback = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TRIR benchmark must be a valid number.')),
      );
      return;
    }

    setState(() => _savingTrir = true);
    try {
      await _repo.updateSetting(token, 'trir_benchmark', value);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('TRIR benchmark saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingTrir = false);
    }
  }

  Future<void> _saveEscalation() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    final value = _escalationController.text.trim();

    setState(() => _savingEscalation = true);
    try {
      await _repo.updateSetting(token, 'escalation_days', value);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Escalation days saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingEscalation = false);
    }
  }

  Future<void> _saveRecurrenceLookback() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    final value = _recurrenceLookbackController.text.trim();
    if (int.tryParse(value) == null || int.parse(value) < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lookback window must be a positive whole number.'),
        ),
      );
      return;
    }

    setState(() => _savingRecurrenceLookback = true);
    try {
      await _repo.updateSetting(token, 'recurrence_lookback_months', value);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lookback window saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingRecurrenceLookback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADMIN SETTINGS'),
        actions: [
          IconButton(
            tooltip: 'Refresh settings',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: HerzogColors.errorRed),
          const SizedBox(height: 12),
          Text('Failed to load settings', style: HerzogText.body()),
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
            style: HerzogText.body(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
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
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Save TRIR benchmark',
                child: ElevatedButton(
                  onPressed: _savingTrir ? null : _saveTrir,
                  child: _savingTrir
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HerzogColors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),

          // ----------------------------------------------------------------
          // Escalation Notifications
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'ESCALATION NOTIFICATIONS'),
          Text(
            'Comma-separated days after which an incident is escalated '
            '(JSON array, e.g. [3,7,14]).',
            style: HerzogText.body(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: 'Escalation days JSON array',
                  child: TextFormField(
                    controller: _escalationController,
                    decoration: const InputDecoration(
                      labelText: 'Escalation days (JSON array)',
                      hintText: '[3,7,14]',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Save escalation days',
                child: ElevatedButton(
                  onPressed: _savingEscalation ? null : _saveEscalation,
                  child: _savingEscalation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HerzogColors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),

          // ----------------------------------------------------------------
          // Recurrence Detection
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'RECURRENCE DETECTION'),
          Text(
            'Number of months to look back when scanning for recurring '
            'incidents.',
            style: HerzogText.body(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
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
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Save recurrence lookback window',
                child: ElevatedButton(
                  onPressed: _savingRecurrenceLookback
                      ? null
                      : _saveRecurrenceLookback,
                  child: _savingRecurrenceLookback
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HerzogColors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),

          // ----------------------------------------------------------------
          // Factor Types
          // ----------------------------------------------------------------
          const SettingSectionHeader(title: 'CONTRIBUTING FACTOR TYPES'),
          Text(
            'Manage the factor types available during incident investigations.',
            style: HerzogText.body(),
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
            style: HerzogText.body(),
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
            style: HerzogText.body(),
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
            style: HerzogText.body(),
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
        ],
      ),
    );
  }
}
