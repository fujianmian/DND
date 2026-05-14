import 'package:flutter/material.dart';

import '../database/database.dart';
import '../theme/app_theme.dart';

class LocationTriggerFields extends StatelessWidget {
  const LocationTriggerFields({
    super.key,
    required this.activeSavedLocations,
    required this.savedLocationId,
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.onSavedLocationSelected,
    required this.onPickCustomLocation,
  });

  final Stream<List<SavedLocation>> activeSavedLocations;
  final int? savedLocationId;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final int? radius;
  final ValueChanged<SavedLocation> onSavedLocationSelected;
  final VoidCallback onPickCustomLocation;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedLocation>>(
      stream: activeSavedLocations,
      builder: (context, snapshot) {
        final savedLocations = snapshot.data ?? const <SavedLocation>[];
        final selectedSavedLocation = _savedLocationById(
          savedLocations,
          savedLocationId,
        );
        final usesMissingSavedLocation =
            savedLocationId != null && selectedSavedLocation == null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SelectionSummary(
              latitude: latitude,
              longitude: longitude,
              radius: radius,
              locationLabel:
                  selectedSavedLocation?.name ?? _cleanText(locationLabel),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (savedLocations.isEmpty)
              Text(
                'No saved locations yet. You can add them in Settings or pick a custom location.',
                style: TextStyle(
                  color: AppTheme.pureBlack.withValues(alpha: 0.62),
                ),
              )
            else
              DropdownButtonFormField<int>(
                key: ValueKey('saved-location-$savedLocationId'),
                initialValue: selectedSavedLocation?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Saved location',
                  border: OutlineInputBorder(),
                ),
                items: savedLocations.map((location) {
                  return DropdownMenuItem<int>(
                    value: location.id,
                    child: Text(location.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final selected = _savedLocationById(savedLocations, id);
                  if (selected != null) {
                    onSavedLocationSelected(selected);
                  }
                },
              ),
            if (usesMissingSavedLocation) ...[
              const SizedBox(height: 8),
              Text(
                'This rule uses a saved location snapshot.',
                style: TextStyle(
                  color: AppTheme.pureBlack.withValues(alpha: 0.62),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickCustomLocation,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Pick custom location'),
            ),
          ],
        );
      },
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.locationLabel,
  });

  final double? latitude;
  final double? longitude;
  final int? radius;
  final String? locationLabel;

  @override
  Widget build(BuildContext context) {
    final title = _title();
    final subtitle = _subtitle();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place, color: AppTheme.logoBlue),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  String _title() {
    final label = _cleanText(locationLabel);
    if (label != null) return label;
    if (latitude == null || longitude == null) return 'Location not selected';
    return 'Lat: ${latitude!.toStringAsFixed(4)}, Lng: ${longitude!.toStringAsFixed(4)}';
  }

  String? _subtitle() {
    if (radius == null) return null;
    if (radius! < 100) {
      return 'Radius: ${radius}m - 100m+ recommended for reliability';
    }
    return 'Radius: ${radius}m';
  }
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

SavedLocation? _savedLocationById(List<SavedLocation> locations, int? id) {
  if (id == null) return null;
  for (final location in locations) {
    if (location.id == id) return location;
  }
  return null;
}
