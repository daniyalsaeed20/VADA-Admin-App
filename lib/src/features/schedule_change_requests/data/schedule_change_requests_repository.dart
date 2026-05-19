import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../whereabouts/domain/whereabouts_entry.dart';
import '../domain/schedule_change_request.dart';
import 'schedule_apply_mapper.dart';

class ScheduleChangeRequestsRepository {
  const ScheduleChangeRequestsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(FirestoreCollections.scheduleChangeRequests);

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection(FirestoreCollections.schedules);

  Stream<List<ScheduleChangeRequest>> watchRequests() {
    return _requests.snapshots().map((snapshot) {
      final items = snapshot.docs
          .where((doc) => doc.id != FirestoreCollections.metaDoc)
          .map(ScheduleChangeRequest.fromFirestore)
          .toList();

      items.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) {
          return b.id.compareTo(a.id);
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  Future<WhereaboutsEntry?> getSchedule(String scheduleId) async {
    if (scheduleId.trim().isEmpty) {
      return null;
    }
    final doc = await _schedules.doc(scheduleId.trim()).get();
    if (!doc.exists) {
      return null;
    }
    return WhereaboutsEntry.fromFirestore(doc);
  }

  Future<void> reviewRequest({
    required String requestId,
    required bool approve,
    required String adminNotes,
    required String reviewedBy,
    required ScheduleChangeRequest request,
    String? scheduleIdOverride,
    Map<String, dynamic>? requestedChangesOverride,
    Map<String, dynamic>? appliedSnapshot,
    bool skipScheduleApply = false,
  }) async {
    final now = FieldValue.serverTimestamp();
    final status =
        approve ? ScheduleChangeRequestStatus.approved : ScheduleChangeRequestStatus.rejected;

    final update = <String, dynamic>{
      'status': status.value,
      'adminNotes': adminNotes.trim(),
      'reviewedAt': now,
      'reviewedBy': reviewedBy.trim(),
      'updatedAt': now,
    };

    final scheduleId =
        scheduleIdOverride?.trim() ?? request.scheduleId?.trim() ?? '';
    if (scheduleId.isNotEmpty &&
        (request.scheduleId == null || request.scheduleId!.trim().isEmpty)) {
      update['scheduleId'] = scheduleId;
    }
    if (appliedSnapshot != null && appliedSnapshot.isNotEmpty) {
      update['appliedSnapshot'] = appliedSnapshot;
    }

    await _requests.doc(requestId).update(update);

    if (!approve || skipScheduleApply) {
      return;
    }

    if (scheduleId.isEmpty) {
      return;
    }

    final changes = requestedChangesOverride ?? request.requestedChanges;
    if (!hasScheduleApplyFields(changes)) {
      return;
    }

    await _applyRequestedChangesToSchedule(
      scheduleId: scheduleId,
      fighterId: request.fighterId,
      requestedChanges: changes,
    );
  }

  Future<void> _applyRequestedChangesToSchedule({
    required String scheduleId,
    required String fighterId,
    required Map<String, dynamic> requestedChanges,
  }) async {
    final doc = await _schedules.doc(scheduleId).get();
    if (!doc.exists) {
      return;
    }
    final existing = WhereaboutsEntry.fromFirestore(doc);
    final patch = await ScheduleApplyMapper(_firestore).buildPatch(
      requestedChanges: requestedChanges,
      fighterId: fighterId,
      existing: existing,
    );

    if (patch.length <= 2) {
      // Only fighterId + updatedAt — nothing to apply.
      return;
    }

    await _schedules.doc(scheduleId).set(patch, SetOptions(merge: true));
  }
}
