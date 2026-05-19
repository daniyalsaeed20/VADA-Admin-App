/// Admin choices when approving a request that needs location / schedule setup.
class ApproveLocationSetup {
  const ApproveLocationSetup.existing({
    required this.existingLocationId,
  })  : createNewLocation = false,
        locationName = '',
        locationAddress = '',
        locationType = 'testing';

  const ApproveLocationSetup.create({
    required this.locationName,
    required this.locationAddress,
    this.locationType = 'testing',
  })  : createNewLocation = true,
        existingLocationId = null;

  final bool createNewLocation;
  final String? existingLocationId;
  final String locationName;
  final String locationAddress;
  final String locationType;
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
