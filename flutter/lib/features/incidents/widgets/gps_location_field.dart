import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/herzog_theme.dart';
import '../../../shared/widgets/app_text_field.dart';

/// A text field with a GPS auto-fill button that retrieves the device location
/// using the geolocator package.
///
/// On tap, the GPS button requests location permission (if needed) and fills
/// the text field with "lat, lon" coordinates. The [onLocationObtained]
/// callback provides the raw lat/lon values for separate storage.
class GpsLocationField extends StatefulWidget {
  /// Field label.
  final String label;

  /// Text controller for the location string.
  final TextEditingController controller;

  /// Called when GPS coordinates are obtained.
  final void Function(double latitude, double longitude)? onLocationObtained;

  /// Validation function.
  final String? Function(String?)? validator;

  /// Whether the field is required.
  final bool required;

  /// Whether the field is enabled.
  final bool enabled;

  /// Called when the text value changes.
  final ValueChanged<String>? onChanged;

  const GpsLocationField({
    super.key,
    required this.label,
    required this.controller,
    this.onLocationObtained,
    this.validator,
    this.required = false,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<GpsLocationField> createState() => _GpsLocationFieldState();
}

class _GpsLocationFieldState extends State<GpsLocationField> {
  bool _loading = false;

  Future<void> _getLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        widget.controller.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        widget.onLocationObtained?.call(position.latitude, position.longitude);
        widget.onChanged?.call(widget.controller.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextField(
            label: widget.label,
            controller: widget.controller,
            hint: 'Enter location or use GPS',
            validator: widget.validator,
            required: widget.required,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Semantics(
            label: 'Auto-fill location from GPS',
            button: true,
            child: IconButton(
              onPressed: widget.enabled && !_loading ? _getLocation : null,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          HerzogColors.navyBlue,
                        ),
                      ),
                    )
                  : const Icon(Icons.my_location, color: HerzogColors.navyBlue),
              tooltip: 'Get current GPS location',
            ),
          ),
        ),
      ],
    );
  }
}
