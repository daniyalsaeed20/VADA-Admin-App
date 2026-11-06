import 'location_record.dart';

/// Finds the directory [LocationRecord] that a schedule / request refers to,
/// so its coordinates can be shown on a map.
///
/// Matches by [id] first, then falls back to an exact (case-insensitive)
/// [name] match for records that only stored a location name.
LocationRecord? findLocationRecord({
  required Iterable<LocationRecord> locations,
  String? id,
  String? name,
}) {
  final trimmedId = id?.trim() ?? '';
  if (trimmedId.isNotEmpty) {
    for (final location in locations) {
      if (location.id == trimmedId) {
        return location;
      }
    }
  }
  final trimmedName = name?.trim().toLowerCase() ?? '';
  if (trimmedName.isEmpty) {
    return null;
  }
  for (final location in locations) {
    if (location.name.trim().toLowerCase() == trimmedName) {
      return location;
    }
  }
  return null;
}

/// A point on the map.
typedef MapCoordinates = ({double latitude, double longitude});

/// Coordinates the fighter picked on the map in the mobile app, stored as
/// `locationLatitude` / `locationLongitude` on a schedule, a request snapshot
/// or a request's `requestedChanges`.
MapCoordinates? readPickedCoordinates(Map<String, dynamic>? data) {
  final lat = data?['locationLatitude'];
  final lng = data?['locationLongitude'];
  if (lat is num && lng is num) {
    return (latitude: lat.toDouble(), longitude: lng.toDouble());
  }
  return null;
}

MapCoordinates? coordinatesOf(LocationRecord? location) {
  final lat = location?.latitude;
  final lng = location?.longitude;
  if (lat == null || lng == null) {
    return null;
  }
  return (latitude: lat, longitude: lng);
}
