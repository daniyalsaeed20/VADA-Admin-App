import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../locations/data/locations_repository.dart';
import '../../whereabouts/data/whereabouts_repository.dart';
import '../../whereabouts/domain/whereabouts_entry.dart';
import '../domain/approve_location_setup.dart';
import '../domain/schedule_change_approve_helpers.dart';
import '../domain/schedule_change_request.dart';
import 'schedule_apply_mapper.dart';
import 'schedule_change_requests_repository.dart';

/// Orchestrates approve + optional location directory setup + schedule create/apply.
class ScheduleChangeApprovalService {
  const ScheduleChangeApprovalService({
    required ScheduleChangeRequestsRepository requests,
    required LocationsRepository locations,
    required WhereaboutsRepository whereabouts,
    required FirebaseFirestore firestore,
  })  : _requests = requests,
        _locations = locations,
        _whereabouts = whereabouts,
        _firestore = firestore;

  final ScheduleChangeRequestsRepository _requests;
  final LocationsRepository _locations;
  final WhereaboutsRepository _whereabouts;
  final FirebaseFirestore _firestore;

  Future<({String? scheduleId, Map<String, dynamic> effectiveChanges})>
      approveWithSetup({
    required ScheduleChangeRequest request,
    required String reviewedBy,
    required ApproveWithSetupOptions options,
  }) async {
    final changes = Map<String, dynamic>.from(request.requestedChanges);
    var scheduleId = request.scheduleId?.trim() ?? '';

    if (options.locationSetup != null) {
      final resolved = await _resolveLocation(
        setup: options.locationSetup!,
        fighterId: request.fighterId,
      );
      changes['locationId'] = resolved.locationId;
      changes['locationName'] = resolved.locationName;
    } else {
      final locationId = readScheduleField(changes, const [
        'locationId',
        'selectedLocation',
      ]);
      if (locationId.isNotEmpty) {
        await _locations.ensureFighterAssignedToLocation(
          locationId: locationId,
          fighterId: request.fighterId,
        );
        final loc = await _locations.getLocation(locationId);
        if (loc != null) {
          changes['locationName'] = loc.name;
        }
      }
    }

    if (scheduleId.isEmpty && options.createScheduleIfMissing) {
      scheduleId = await _createScheduleFromRequest(
        request: request,
        changes: changes,
      );
    }

    Map<String, dynamic>? appliedSnapshot;
    if (scheduleId.isNotEmpty && hasScheduleApplyFields(changes)) {
      appliedSnapshot = await _applyToSchedule(
        scheduleId: scheduleId,
        fighterId: request.fighterId,
        requestedChanges: changes,
      );
    }

    await _requests.reviewRequest(
      requestId: request.id,
      approve: true,
      adminNotes: options.adminNotes,
      reviewedBy: reviewedBy,
      request: request,
      scheduleIdOverride: scheduleId.isEmpty ? null : scheduleId,
      requestedChangesOverride: changes,
      skipScheduleApply: true,
      appliedSnapshot: appliedSnapshot,
    );

    return (
      scheduleId: scheduleId.isEmpty ? null : scheduleId,
      effectiveChanges: changes,
    );
  }

  Future<({String locationId, String locationName})> _resolveLocation({
    required ApproveLocationSetup setup,
    required String fighterId,
  }) async {
    if (setup.createNewLocation) {
      final id = await _locations.createLocation(
        name: setup.locationName,
        address: setup.locationAddress,
        type: setup.locationType,
        assignedFighterIds: [fighterId],
      );
      return (locationId: id, locationName: setup.locationName.trim());
    }

    final id = setup.existingLocationId?.trim() ?? '';
    if (id.isEmpty) {
      throw StateError('Select a location from the directory.');
    }

    await _locations.ensureFighterAssignedToLocation(
      locationId: id,
      fighterId: fighterId,
    );
    final loc = await _locations.getLocation(id);
    return (
      locationId: id,
      locationName: loc?.name ?? setup.locationName.trim(),
    );
  }

  Future<String> _createScheduleFromRequest({
    required ScheduleChangeRequest request,
    required Map<String, dynamic> changes,
  }) async {
    final snapshot = request.currentSnapshot;
    final date = readScheduleFieldWithFallback(
      primary: changes,
      fallback: snapshot,
      keys: const ['date', 'scheduleDate'],
    );
    if (date.isEmpty) {
      throw StateError('Cannot create schedule: date is missing from the request.');
    }

    final startTime = readScheduleFieldWithFallback(
      primary: changes,
      fallback: snapshot,
      keys: const ['startTime', 'fromTime', 'start'],
    );
    final endTime = readScheduleFieldWithFallback(
      primary: changes,
      fallback: snapshot,
      keys: const ['endTime', 'toTime', 'end'],
    );
    if (startTime.isEmpty || endTime.isEmpty) {
      throw StateError('Cannot create schedule: start or end time is missing.');
    }

    final locationId = readScheduleField(changes, const ['locationId']);
    if (locationId.isEmpty) {
      throw StateError('Cannot create schedule: assign or create a location first.');
    }

    final contactId = readScheduleFieldWithFallback(
      primary: changes,
      fallback: snapshot,
      keys: const ['contactId', 'selectedContact'],
    );
    final recurrence = readScheduleFieldWithFallback(
      primary: changes,
      fallback: snapshot,
      keys: const ['recurrence', 'frequency', 'repeat'],
    );
    final notes = request.notes.trim().isNotEmpty
        ? request.notes.trim()
        : readScheduleFieldWithFallback(
            primary: changes,
            fallback: snapshot,
            keys: const ['notes', 'comment', 'remarks'],
          );

    final scheduleId = await _whereabouts.createWhereabouts(
      fighterId: request.fighterId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      locationId: locationId,
      contactId: contactId,
      notes: notes,
      recurrence: recurrence.isEmpty ? 'daily' : recurrence,
    );

    await _applyToSchedule(
      scheduleId: scheduleId,
      fighterId: request.fighterId,
      requestedChanges: changes,
    );

    return scheduleId;
  }

  Future<Map<String, dynamic>?> _applyToSchedule({
    required String scheduleId,
    required String fighterId,
    required Map<String, dynamic> requestedChanges,
  }) async {
    final doc = await _firestore
        .collection(FirestoreCollections.schedules)
        .doc(scheduleId)
        .get();
    if (!doc.exists) {
      return null;
    }
    final existing = WhereaboutsEntry.fromFirestore(doc);
    final patch = await ScheduleApplyMapper(_firestore).buildPatch(
      requestedChanges: requestedChanges,
      fighterId: fighterId,
      existing: existing,
    );
    if (patch.length <= 2) {
      return null;
    }
    await _firestore
        .collection(FirestoreCollections.schedules)
        .doc(scheduleId)
        .set(patch, SetOptions(merge: true));
    return patch;
  }
}
