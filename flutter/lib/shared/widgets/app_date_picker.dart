import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/herzog_theme.dart';

/// Herzog-styled date picker trigger field.
///
/// Renders a tappable text field that opens the Flutter date picker dialog.
/// Supports label, required marker, validation, and semantic label for ADA.
///
/// Usage:
/// ```dart
/// AppDatePicker(
///   label: 'Incident Date',
///   required: true,
///   selectedDate: _incidentDate,
///   onDateSelected: (date) => setState(() => _incidentDate = date),
///   validator: (d) => d == null ? 'Date required' : null,
/// )
/// ```
class AppDatePicker extends StatelessWidget {
  /// Field label displayed above the input.
  final String label;

  /// Currently selected date.
  final DateTime? selectedDate;

  /// Called when the user picks a date.
  final ValueChanged<DateTime?> onDateSelected;

  /// Validation function. Returns an error string or null.
  final String? Function(DateTime?)? validator;

  /// Whether the field is required (adds * indicator to label).
  final bool required;

  /// Whether the field is enabled.
  final bool enabled;

  /// Earliest selectable date. Defaults to 1 Jan 2000.
  final DateTime? firstDate;

  /// Latest selectable date. Defaults to today + 5 years.
  final DateTime? lastDate;

  /// Semantic label for screen readers. Defaults to [label].
  final String? semanticLabel;

  /// Date display format. Defaults to 'MM/dd/yyyy'.
  final String? displayFormat;

  const AppDatePicker({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    this.validator,
    this.required = false,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
    this.semanticLabel,
    this.displayFormat,
  });

  String _formatDate(DateTime date) {
    final fmt = DateFormat(displayFormat ?? 'MM/dd/yyyy');
    return fmt.format(date);
  }

  Future<void> _pickDate(BuildContext context) async {
    if (!enabled) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        // Apply Herzog theme colors to date picker dialog
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: HerzogColors.navyBlue,
              onPrimary: HerzogColors.white,
              surface: HerzogColors.white,
              onSurface: HerzogColors.darkGray,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = required ? '$label *' : label;
    final effectiveSemanticLabel = semanticLabel ?? label;
    final displayText = selectedDate != null
        ? _formatDate(selectedDate!)
        : null;

    return Semantics(
      label: effectiveSemanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Field label
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              effectiveLabel,
              style: HerzogText.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HerzogColors.darkGray,
              ),
            ),
          ),
          // Date trigger field
          FormField<DateTime>(
            initialValue: selectedDate,
            validator: validator != null
                ? (_) => validator!(selectedDate)
                : null,
            builder: (formState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: enabled ? () => _pickDate(context) : null,
                    borderRadius: BorderRadius.circular(5),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        suffixIcon: const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: HerzogColors.darkGray,
                        ),
                        errorText: formState.errorText,
                        filled: !enabled,
                        fillColor: enabled
                            ? null
                            : HerzogColors.lightGray.withValues(alpha: 0.5),
                      ),
                      isEmpty: displayText == null,
                      child: Text(
                        displayText ?? '',
                        style: displayText != null
                            ? HerzogText.body(
                                fontSize: 14,
                                color: enabled
                                    ? HerzogColors.darkGray
                                    : HerzogColors.smoke,
                              )
                            : HerzogText.body(
                                fontSize: 14,
                                color: HerzogColors.smoke,
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
