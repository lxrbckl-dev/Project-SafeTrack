import 'package:flutter/material.dart';
import '../../app/herzog_theme.dart';

/// Herzog-styled elevated button with loading spinner state.
///
/// When [isLoading] is true, the button shows a [CircularProgressIndicator]
/// and disables further presses to prevent duplicate submissions.
///
/// Usage:
/// ```dart
/// AppLoadingButton(
///   label: 'Submit Report',
///   isLoading: _isSubmitting,
///   onPressed: _isSubmitting ? null : _handleSubmit,
/// )
/// ```
class AppLoadingButton extends StatelessWidget {
  /// Button label text.
  final String label;

  /// Whether the button is in loading state.
  final bool isLoading;

  /// Called when the button is tapped.
  /// Pass null to disable the button.
  final VoidCallback? onPressed;

  /// Optional leading icon (shown when not loading).
  final IconData? icon;

  /// Button style variant.
  final AppButtonVariant variant;

  /// Semantic label for screen readers. Defaults to [label].
  final String? semanticLabel;

  const AppLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.semanticLabel,
  }) : variant = AppButtonVariant.primary;

  const AppLoadingButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.semanticLabel,
  }) : variant = AppButtonVariant.secondary;

  const AppLoadingButton.accent({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.semanticLabel,
  }) : variant = AppButtonVariant.accent;

  @override
  Widget build(BuildContext context) {
    final effectiveSemanticLabel = semanticLabel ?? label;
    final isDisabled = onPressed == null || isLoading;

    Widget buttonChild;
    if (isLoading) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.accent
                    ? HerzogColors.richBlack
                    : HerzogColors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      );
    } else if (icon != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 8), Text(label)],
      );
    } else {
      buttonChild = Text(label);
    }

    return Semantics(
      label: isLoading
          ? 'Loading: $effectiveSemanticLabel'
          : effectiveSemanticLabel,
      button: true,
      enabled: !isDisabled,
      child: switch (variant) {
        AppButtonVariant.primary => ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          child: buttonChild,
        ),
        AppButtonVariant.secondary => OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: HerzogColors.darkGray,
            side: const BorderSide(color: HerzogColors.borderGray),
            textStyle: HerzogText.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: buttonChild,
        ),
        AppButtonVariant.accent => ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: HerzogColors.gold,
            foregroundColor: HerzogColors.richBlack,
            textStyle: HerzogText.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: buttonChild,
        ),
      },
    );
  }
}

/// Button style variant for [AppLoadingButton].
enum AppButtonVariant { primary, secondary, accent }
