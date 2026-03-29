import 'package:flutter/material.dart';
import '../../app/herzog_theme.dart';

/// A dropdown option model.
class AppDropdownOption<T> {
  final T value;
  final String label;

  const AppDropdownOption({required this.value, required this.label});
}

/// Herzog-styled dropdown form field wrapper.
///
/// Wraps [DropdownButtonFormField] with Herzog styling, a label row,
/// and semantic label for ADA/WCAG compliance.
///
/// Usage:
/// ```dart
/// AppDropdown<String>(
///   label: 'Incident Type',
///   options: [
///     AppDropdownOption(value: 'injury', label: 'Injury'),
///     AppDropdownOption(value: 'near_miss', label: 'Near Miss'),
///   ],
///   value: selectedType,
///   onChanged: (v) => setState(() => selectedType = v),
///   validator: (v) => v == null ? 'Required' : null,
/// )
/// ```
class AppDropdown<T> extends StatelessWidget {
  /// Field label displayed above the dropdown.
  final String label;

  /// List of selectable options.
  final List<AppDropdownOption<T>> options;

  /// Currently selected value.
  final T? value;

  /// Called when the user selects a new value.
  final ValueChanged<T?>? onChanged;

  /// Validation function. Returns an error string or null.
  final String? Function(T?)? validator;

  /// Whether the field is required (adds * indicator to label).
  final bool required;

  /// Whether the dropdown is enabled.
  final bool enabled;

  /// Hint text shown when no value is selected.
  final String? hint;

  /// Semantic label for screen readers. Defaults to [label].
  final String? semanticLabel;

  const AppDropdown({
    super.key,
    required this.label,
    required this.options,
    this.value,
    this.onChanged,
    this.validator,
    this.required = false,
    this.enabled = true,
    this.hint,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = required ? '$label *' : label;
    final effectiveSemanticLabel = semanticLabel ?? label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark
                    ? HerzogDarkColors.textSecondary
                    : HerzogColors.darkGray,
              ),
            ),
          ),
          // Dropdown field
          DropdownButtonFormField<T>(
            initialValue: value,
            onChanged: enabled ? onChanged : null,
            validator: validator,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: isDark
                  ? HerzogDarkColors.textSecondary
                  : HerzogColors.darkGray,
            ),
            dropdownColor: isDark
                ? HerzogDarkColors.surfaceVariant
                : HerzogColors.white,
            style: HerzogText.body(
              fontSize: 14,
              color: isDark ? Colors.white : HerzogColors.darkGray,
            ),
            hint: hint != null
                ? Text(
                    hint!,
                    style: HerzogText.body(
                      fontSize: 14,
                      color: isDark
                          ? HerzogDarkColors.textMuted
                          : HerzogColors.smoke,
                    ),
                  )
                : null,
            decoration: InputDecoration(
              filled: !enabled,
              fillColor: enabled
                  ? null
                  : isDark
                      ? HerzogDarkColors.surface.withValues(alpha: 0.5)
                      : HerzogColors.lightGray.withValues(alpha: 0.5),
            ),
            items: options
                .map(
                  (opt) => DropdownMenuItem<T>(
                    value: opt.value,
                    child: Text(opt.label),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
