import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/incident_repository.dart';
import '../widgets/status_badge.dart';

/// Full-page map view displaying incidents as color-coded markers.
///
/// Features:
/// - OpenStreetMap tiles (free, no API key)
/// - Markers color-coded by severity
/// - Tap marker to show popup card with incident details
/// - Filter controls: type, severity, status
/// - "My Location" floating button via geolocator
/// - Route: /incidents/map
/// - ADA: semantic labels on all markers and controls
class IncidentMapPage extends StatefulWidget {
  const IncidentMapPage({super.key});

  @override
  State<IncidentMapPage> createState() => _IncidentMapPageState();
}

class _IncidentMapPageState extends State<IncidentMapPage> {
  late final IncidentRepository _repo;
  final MapController _mapController = MapController();

  List<Incident> _incidents = [];
  bool _loading = true;
  String? _error;

  // Filters
  String? _typeFilter;
  String? _severityFilter;
  String? _statusFilter;

  // Selected incident for popup
  Incident? _selectedIncident;

  static const _incidentTypes = [
    'Injury',
    'Near Miss',
    'Property Damage',
    'Environmental',
    'Vehicle',
    'Fire',
    'Utility Strike',
  ];

  static const _severities = [
    'Fatality',
    'Lost Time',
    'Medical Treatment',
    'First Aid',
    'Near Miss',
  ];

  static const _statuses = [
    'Draft',
    'Reported',
    'Under Investigation',
    'Investigation Complete',
    'CAPA Assigned',
    'CAPA In Progress',
    'Closed',
    'Reopened',
  ];

  // Default center: continental US
  static const _defaultCenter = LatLng(39.8283, -98.5795);
  static const _defaultZoom = 4.5;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _repo = IncidentRepository(auth);
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _repo.listIncidents(
        status: _statusFilter,
        type: _typeFilter,
        perPage: 500, // Load more for map view
      );
      if (mounted) {
        setState(() {
          _incidents = response.data;
          _loading = false;
        });
        _fitMapToIncidents();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Adjusts the map bounds to fit all visible incidents.
  void _fitMapToIncidents() {
    final filtered = _filteredIncidents;
    final withCoords = filtered
        .where((i) => i.latitude != 0.0 || i.longitude != 0.0)
        .toList();
    if (withCoords.isEmpty) return;

    if (withCoords.length == 1) {
      _mapController.move(
        LatLng(withCoords.first.latitude, withCoords.first.longitude),
        12.0,
      );
      return;
    }

    final lats = withCoords.map((i) => i.latitude);
    final lngs = withCoords.map((i) => i.longitude);
    final bounds = LatLngBounds(
      LatLng(
        lats.reduce((a, b) => a < b ? a : b),
        lngs.reduce((a, b) => a < b ? a : b),
      ),
      LatLng(
        lats.reduce((a, b) => a > b ? a : b),
        lngs.reduce((a, b) => a > b ? a : b),
      ),
    );

    try {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } catch (_) {
      // Map may not be ready yet; ignore
    }
  }

  /// Returns incidents filtered by the currently selected severity filter.
  List<Incident> get _filteredIncidents {
    var result = _incidents;
    if (_severityFilter != null) {
      result = result
          .where(
            (i) => i.severity.toLowerCase() == _severityFilter!.toLowerCase(),
          )
          .toList();
    }
    return result;
  }

  /// Returns the marker color based on incident severity.
  Color _severityMarkerColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'fatality':
      case 'lost time':
        return HerzogColors.errorRed;
      case 'medical treatment':
        return HerzogColors.warningAmber;
      case 'first aid':
        return HerzogColors.infoTeal;
      case 'near miss':
        return HerzogColors.successGreen;
      default:
        return HerzogColors.midGray;
    }
  }

  /// Returns the icon for an incident type.
  IconData _iconForType(String type) {
    switch (type) {
      case 'Injury':
        return Icons.personal_injury;
      case 'Near Miss':
        return Icons.warning_amber;
      case 'Property Damage':
        return Icons.domain_disabled;
      case 'Environmental':
        return Icons.eco;
      case 'Vehicle':
        return Icons.directions_car;
      case 'Fire':
        return Icons.local_fire_department;
      case 'Utility Strike':
        return Icons.flash_on;
      default:
        return Icons.report_problem;
    }
  }

  /// Attempts to center the map on the user's current location.
  Future<void> _goToMyLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled.'),
              backgroundColor: HerzogColors.warningAmber,
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied.'),
                backgroundColor: HerzogColors.warningAmber,
              ),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission permanently denied. '
                'Enable it in your device settings.',
              ),
              backgroundColor: HerzogColors.warningAmber,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          14.0,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get location: $e'),
            backgroundColor: HerzogColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INCIDENT MAP'),
        leading: Semantics(
          label: 'Back to incident list',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/incidents'),
          ),
        ),
        actions: [
          Semantics(
            label: 'Switch to list view',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'List view',
              onPressed: () => context.go('/incidents'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : _buildMap(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Center map on my current location',
            button: true,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              onPressed: _goToMyLocation,
              backgroundColor: HerzogColors.white,
              foregroundColor: HerzogColors.navyBlue,
              child: const Icon(Icons.my_location),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Fit map to show all incidents',
            button: true,
            child: FloatingActionButton.small(
              heroTag: 'fitAll',
              onPressed: _fitMapToIncidents,
              backgroundColor: HerzogColors.white,
              foregroundColor: HerzogColors.navyBlue,
              child: const Icon(Icons.zoom_out_map),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: HerzogColors.white,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _MapFilterDropdown(
            label: 'Type',
            value: _typeFilter,
            items: _incidentTypes,
            onChanged: (v) {
              setState(() => _typeFilter = v);
              _loadIncidents();
            },
          ),
          _MapFilterDropdown(
            label: 'Severity',
            value: _severityFilter,
            items: _severities,
            onChanged: (v) {
              setState(() => _severityFilter = v);
              _fitMapToIncidents();
            },
          ),
          _MapFilterDropdown(
            label: 'Status',
            value: _statusFilter,
            items: _statuses,
            onChanged: (v) {
              setState(() => _statusFilter = v);
              _loadIncidents();
            },
          ),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      children: [
        _legendDot(HerzogColors.errorRed, 'Fatality/Lost Time'),
        _legendDot(HerzogColors.warningAmber, 'Medical Treatment'),
        _legendDot(HerzogColors.infoTeal, 'First Aid'),
        _legendDot(HerzogColors.successGreen, 'Near Miss'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: HerzogText.body(fontSize: 11)),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: HerzogColors.errorRed,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load incidents',
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(color: HerzogColors.midGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadIncidents,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final filtered = _filteredIncidents;
    final markers = <Marker>[];

    for (final incident in filtered) {
      // Skip incidents without valid coordinates
      if (incident.latitude == 0.0 && incident.longitude == 0.0) continue;

      final color = _severityMarkerColor(incident.severity);
      final isSelected = _selectedIncident?.id == incident.id;

      markers.add(
        Marker(
          point: LatLng(incident.latitude, incident.longitude),
          width: isSelected ? 44 : 36,
          height: isSelected ? 44 : 36,
          child: Semantics(
            label:
                '${incident.type} incident, severity ${incident.severity}, '
                'status ${incident.status}, at ${incident.location}',
            button: true,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIncident = _selectedIncident?.id == incident.id
                      ? null
                      : incident;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? HerzogColors.gold : HerzogColors.white,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: isSelected ? 8 : 4,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _iconForType(incident.type),
                  color: HerzogColors.white,
                  size: isSelected ? 20 : 16,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: _defaultZoom,
            onTap: (_, _) {
              if (_selectedIncident != null) {
                setState(() => _selectedIncident = null);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.herzog.safetrack',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Incident count badge
        Positioned(
          top: 8,
          left: 8,
          child: _buildIncidentCountBadge(markers.length, filtered.length),
        ),
        // Popup card for selected incident
        if (_selectedIncident != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _IncidentPopupCard(
              incident: _selectedIncident!,
              iconForType: _iconForType,
              severityColor: _severityMarkerColor,
              onViewDetails: () {
                if (_selectedIncident?.id != null) {
                  context.go('/incidents/${_selectedIncident!.id}');
                }
              },
              onDismiss: () {
                setState(() => _selectedIncident = null);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildIncidentCountBadge(int markerCount, int totalFiltered) {
    final noCoords = totalFiltered - markerCount;
    return Semantics(
      label:
          '$markerCount incidents shown on map'
          '${noCoords > 0 ? ', $noCoords without coordinates' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: HerzogColors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: HerzogColors.richBlack.withValues(alpha: 0.15),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, size: 16, color: HerzogColors.navyBlue),
            const SizedBox(width: 4),
            Text(
              '$markerCount incident${markerCount == 1 ? '' : 's'}',
              style: HerzogText.body(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HerzogColors.navyBlue,
              ),
            ),
            if (noCoords > 0) ...[
              const SizedBox(width: 8),
              Text(
                '($noCoords no GPS)',
                style: HerzogText.body(fontSize: 11, color: HerzogColors.smoke),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Popup card shown when a map marker is tapped.
class _IncidentPopupCard extends StatelessWidget {
  final Incident incident;
  final IconData Function(String) iconForType;
  final Color Function(String) severityColor;
  final VoidCallback onViewDetails;
  final VoidCallback onDismiss;

  const _IncidentPopupCard({
    required this.incident,
    required this.iconForType,
    required this.severityColor,
    required this.onViewDetails,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = incident.date != null
        ? DateFormat('MM/dd/yyyy').format(incident.date!)
        : 'No date';
    final color = severityColor(incident.severity);

    return Semantics(
      label:
          '${incident.type} incident details popup. '
          'Date: $dateStr. '
          'Severity: ${incident.severity}. '
          'Status: ${incident.status}. '
          'Tap View Details to open full incident.',
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconForType(incident.type),
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.type.isNotEmpty ? incident.type : 'Untitled',
                          style: HerzogText.body(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: HerzogColors.richBlack,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: HerzogText.body(
                            fontSize: 12,
                            color: HerzogColors.midGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Dismiss popup',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onDismiss,
                      color: HerzogColors.smoke,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Severity and status row
              Row(
                children: [
                  if (incident.severity.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          incident.severity,
                          style: HerzogText.body(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  StatusBadge(status: incident.status),
                ],
              ),
              // Description snippet
              if (incident.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  incident.description,
                  style: HerzogText.body(
                    fontSize: 13,
                    color: HerzogColors.darkGray,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Location
              if (incident.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: HerzogColors.smoke,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        incident.location,
                        style: HerzogText.body(
                          fontSize: 12,
                          color: HerzogColors.smoke,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // View Details button
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  label: 'View full details for this ${incident.type} incident',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('VIEW DETAILS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HerzogColors.navyBlue,
                      foregroundColor: HerzogColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact filter dropdown for the map filter bar.
class _MapFilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _MapFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: HerzogText.label(fontSize: 11),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        style: HerzogText.body(fontSize: 13, color: HerzogColors.darkGray),
        dropdownColor: HerzogColors.white,
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('All', style: HerzogText.body(fontSize: 13)),
          ),
          ...items.map(
            (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
