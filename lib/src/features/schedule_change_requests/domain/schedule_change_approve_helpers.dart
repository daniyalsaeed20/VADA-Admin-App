import 'schedule_change_request.dart';

/// Mobile may send explicit new-site fields, or legacy `proposedLocationText`.
String readRequestedNewSiteName(Map<String, dynamic> changes) {
  final direct = readScheduleField(changes, const [
    'locationName',
    'location',
    'newLocationName',
  ]);
  if (direct.isNotEmpty) {
    return direct;
  }
  return parseProposedLocationText(
    readScheduleField(changes, const ['proposedLocationText']),
  ).name;
}

String readRequestedNewSiteAddress(Map<String, dynamic> changes) {
  final direct = readScheduleField(changes, const [
    'locationAddress',
    'siteAddress',
    'newLocationAddress',
  ]);
  if (direct.isNotEmpty) {
    return direct;
  }
  return parseProposedLocationText(
    readScheduleField(changes, const ['proposedLocationText']),
  ).address;
}

/// Single-line or two-line summary for UI and denormalized `proposedLocationText`.
String readRequestedNewSiteSummary(Map<String, dynamic> changes) {
  final name = readRequestedNewSiteName(changes);
  final addr = readRequestedNewSiteAddress(changes);
  if (name.isEmpty && addr.isEmpty) {
    return '';
  }
  if (addr.isEmpty || addr == name) {
    return name;
  }
  if (name.isEmpty) {
    return addr;
  }
  return '$name\n$addr';
}

/// Whether admin must confirm location directory setup before approve.
bool needsApproveLocationSetup(ScheduleChangeRequest request) {
  if (request.requestType == ScheduleChangeRequestType.newLocation) {
    return true;
  }

  final locationId = readScheduleField(
    request.requestedChanges,
    const ['locationId', 'selectedLocation'],
  );
  if (locationId.isNotEmpty) {
    return false;
  }

  return readRequestedNewSiteSummary(request.requestedChanges).isNotEmpty;
}

bool needsCreateScheduleOnApprove(ScheduleChangeRequest request) {
  return (request.scheduleId?.trim() ?? '').isEmpty;
}

bool needsApproveSetupDialog(ScheduleChangeRequest request) {
  return needsApproveLocationSetup(request) ||
      needsCreateScheduleOnApprove(request);
}

/// Splits fighter free-text into a display name and address for the location form.
({String name, String address}) parseProposedLocationText(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return (name: '', address: '');
  }
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return (name: text, address: text);
  }
  if (lines.length == 1) {
    return (name: lines.first, address: lines.first);
  }
  return (name: lines.first, address: lines.join('\n'));
}

String readScheduleFieldWithFallback({
  required Map<String, dynamic> primary,
  required Map<String, dynamic> fallback,
  required List<String> keys,
}) {
  final fromPrimary = readScheduleField(primary, keys);
  if (fromPrimary.isNotEmpty) {
    return fromPrimary;
  }
  return readScheduleField(fallback, keys);
}
