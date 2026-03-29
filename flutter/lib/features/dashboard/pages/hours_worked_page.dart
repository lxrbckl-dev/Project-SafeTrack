import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/dashboard_repository.dart';

/// Page for Safety Managers to enter total hours worked per reporting period.
///
/// Shows an entry form at the top and a list of existing entries below.
class HoursWorkedPage extends StatefulWidget {
  const HoursWorkedPage({super.key});

  @override
  State<HoursWorkedPage> createState() => _HoursWorkedPageState();
}

class _HoursWorkedPageState extends State<HoursWorkedPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _periodStart;
  DateTime? _periodEnd;
  final _hoursController = TextEditingController();
  final _divisionController = TextEditingController();

  List<HoursWorked> _entries = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _divisionController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final repo = DashboardRepository(auth);
      final entries = await repo.listHoursWorked();
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_periodStart == null || _periodEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthService>();
      final repo = DashboardRepository(auth);
      final entry = HoursWorked(
        reportingPeriodStart: _periodStart!,
        reportingPeriodEnd: _periodEnd!,
        totalHours: double.parse(_hoursController.text),
        division: _divisionController.text.trim(),
      );
      await repo.createHoursWorked(entry);
      _hoursController.clear();
      _divisionController.clear();
      setState(() {
        _periodStart = null;
        _periodEnd = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hours worked entry created')),
        );
      }
      await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart
        ? (_periodStart ?? DateTime.now())
        : (_periodEnd ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('HOURS WORKED')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Entry form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Text(
                          'NEW ENTRY',
                          style: HerzogText.heading(
                            fontSize: 16,
                            color: isDark ? Colors.white : HerzogColors.richBlack,
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Period Start',
                              value: _periodStart != null
                                  ? dateFmt.format(_periodStart!)
                                  : null,
                              onTap: () => _pickDate(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateField(
                              label: 'Period End',
                              value: _periodEnd != null
                                  ? dateFmt.format(_periodEnd!)
                                  : null,
                              onTap: () => _pickDate(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _hoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Total Hours Worked',
                          hintText: 'e.g. 45000',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Required';
                          }
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) {
                            return 'Enter a positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _divisionController,
                        decoration: const InputDecoration(
                          labelText: 'Division (optional)',
                          hintText: 'e.g. Track',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Existing entries
            Builder(builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Text(
                'EXISTING ENTRIES',
                style: HerzogText.heading(
                  fontSize: 16,
                  color: isDark ? Colors.white : HerzogColors.richBlack,
                ),
              );
            }),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(
                _error!,
                style: HerzogText.body(color: HerzogColors.errorRed),
              )
            else if (_entries.isEmpty)
              Builder(builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  'No hours worked entries yet',
                  style: HerzogText.body(
                    color: isDark ? Colors.white : HerzogColors.smoke,
                  ),
                );
              })
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('PERIOD START')),
                    DataColumn(label: Text('PERIOD END')),
                    DataColumn(label: Text('HOURS'), numeric: true),
                    DataColumn(label: Text('DIVISION')),
                    DataColumn(label: Text('ENTERED BY')),
                  ],
                  rows: _entries.map((e) {
                    return DataRow(
                      cells: [
                        DataCell(Text(dateFmt.format(e.reportingPeriodStart))),
                        DataCell(Text(dateFmt.format(e.reportingPeriodEnd))),
                        DataCell(
                          Text(NumberFormat('#,###.#').format(e.totalHours)),
                        ),
                        DataCell(Text(e.division)),
                        DataCell(Text(e.enteredByUserId)),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tappable date-picker field.
class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Builder(builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Text(
            value ?? 'Select date',
            style: value != null
                ? HerzogText.body(
                    color: isDark ? Colors.white : HerzogColors.richBlack,
                  )
                : HerzogText.body(
                    color: isDark ? Colors.white : HerzogColors.smoke,
                  ),
          );
        }),
      ),
    );
  }
}
