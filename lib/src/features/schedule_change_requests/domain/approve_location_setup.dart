/// Admin choices when approving a request that needs location / schedule setup.
class ApproveLocationSetup {
  const ApproveLocationSetup.existing({
    required this.existingLocationId,
  })  : createNewLocation = false,
        useFighterLocation = false,
        locationName = '',
        locationAddress = '',
        locationType = 'testing',
        latitude = null,
        longitude = null;

  const ApproveLocationSetup.create({
    required this.locationName,
    required this.locationAddress,
    this.locationType = 'testing',
    this.latitude,
    this.longitude,
  })  : createNewLocation = true,
        useFighterLocation = false,
        existingLocationId = null;

  /// Keep the location the fighter picked on the map as-is, without adding
  /// it to the directory.
  const ApproveLocationSetup.fighterLocation()
      : createNewLocation = false,
        useFighterLocation = true,
        existingLocationId = null,
        locationName = '',
        locationAddress = '',
        locationType = 'testing',
        latitude = null,
        longitude = null;

  final bool createNewLocation;
  final bool useFighterLocation;
  final String? existingLocationId;
  final String locationName;
  final String locationAddress;
  final String locationType;
  final double? latitude;
  final double? longitude;
}

class ApproveWithSetupOptions {
  const ApproveWithSetupOptions({
    required this.adminNotes,
    this.locationSetup,
    this.createScheduleIfMissing = true,
  });

  final String adminNotes;
  final ApproveLocationSetup? locationSetup;
  final bool createScheduleIfMissing;
}

/// Result from the guided approve dialog (admin notes added by caller).
class ApproveSetupDialogResult {
  const ApproveSetupDialogResult({
    this.locationSetup,
    required this.createScheduleIfMissing,
  });

  final ApproveLocationSetup? locationSetup;
  final bool createScheduleIfMissing;
}
