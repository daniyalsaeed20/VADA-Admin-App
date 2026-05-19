import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../locations/presentation/locations_controller.dart';
import '../../notifications/domain/schedule_change_notification_queue.dart';
import '../../whereabouts/presentation/whereabouts_controller.dart';
import '../data/schedule_change_approval_service.dart';
import '../data/schedule_change_requests_repository.dart';
import '../domain/approve_location_setup.dart';
import '../domain/schedule_change_request.dart';
import '../../whereabouts/domain/whereabouts_entry.dart';

final scheduleChangeRequestsRepositoryProvider =
    Provider<ScheduleChangeRequestsRepository>((ref) {
  return ScheduleChangeRequestsRepository(ref.watch(firestoreProvider));
});

final scheduleChangeApprovalServiceProvider =
    Provider<ScheduleChangeApprovalService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ScheduleChangeApprovalService(
    requests: ref.watch(scheduleChangeRequestsRepositoryProvider),
    locations: ref.watch(locationsRepositoryProvider),
    whereabouts: ref.watch(whereaboutsRepositoryProvider),
    firestore: firestore,
  );
});

final scheduleChangeRequestsStreamProvider =
    StreamProvider<List<ScheduleChangeRequest>>((ref) {
  return ref.watch(scheduleChangeRequestsRepositoryProvider).watchRequests();
});

final pendingScheduleChangeRequestsCountProvider = Provider<int>((ref) {
  final requests = ref.watch(scheduleChangeRequestsStreamProvider);
  return requests.when(
    data: (items) =>
        items.where((r) => r.status == ScheduleChangeRequestStatus.pending).length,
    loading: () => 0,
    error: (err, st) => 0,
  );
});

final scheduleChangeRequestsTotalCountProvider = Provider<int>((ref) {
  final requests = ref.watch(scheduleChangeRequestsStreamProvider);
  return requests.when(
    data: (items) => items.length,
    loading: () => 0,
    error: (err, st) => 0,
  );
});

final pendingScheduleChangeRequestsProvider =
    Provider<List<ScheduleChangeRequest>>((ref) {
  final requests = ref.watch(scheduleChangeRequestsStreamProvider);
  return requests.when(
    data: (items) => items
        .where((r) => r.status == ScheduleChangeRequestStatus.pending)
        .toList(),
    loading: () => const [],
    error: (err, st) => const [],
  );
});

final pendingScheduleChangeRequestsForFighterProvider =
    Provider.family<int, String>((ref, fighterId) {
  if (fighterId.trim().isEmpty) {
    return 0;
  }
  final pending = ref.watch(pendingScheduleChangeRequestsProvider);
  return pending.where((r) => r.fighterId == fighterId.trim()).length;
});

final scheduleByIdProvider =
    FutureProvider.family<WhereaboutsEntry?, String>((ref, scheduleId) {
  if (scheduleId.trim().isEmpty) {
    return Future.value(null);
  }
  return ref
      .watch(scheduleChangeRequestsRepositoryProvider)
      .getSchedule(scheduleId);
});

class ScheduleChangeRequestMutationState {
  const ScheduleChangeRequestMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  ScheduleChangeRequestMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ScheduleChangeRequestMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ScheduleChangeRequestMutationController
    extends StateNotifier<ScheduleChangeRequestMutationState> {
  ScheduleChangeRequestMutationController(this._ref)
      : super(const ScheduleChangeRequestMutationState());

  final Ref _ref;

  Future<void> approve({
    required ScheduleChangeRequest request,
    required String adminNotes,
  }) async {
    await _review(request: request, approve: true, adminNotes: adminNotes);
  }

  Future<void> approveWithSetup({
    required ScheduleChangeRequest request,
    required ApproveWithSetupOptions options,
  }) async {
    if (!request.isPending) {
      return;
    }

    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final user = _ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        throw StateError('Not signed in');
      }

      final result = await _ref.read(scheduleChangeApprovalServiceProvider).approveWithSetup(
            request: request,
            reviewedBy: user.uid,
            options: options,
          );

      await _ref.read(scheduleChangeNotificationQueueProvider).queueResolution(
            request: request,
            approved: true,
            adminNotes: options.adminNotes,
            scheduleIdOverride: result.scheduleId,
            requestedChangesOverride: result.effectiveChanges,
          );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Request approved and schedule updated.',
      );
    } on StateError catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not complete approval. Please try again.',
      );
    }
  }

  Future<void> reject({
    required ScheduleChangeRequest request,
    required String adminNotes,
  }) async {
    await _review(request: request, approve: false, adminNotes: adminNotes);
  }

  Future<void> _review({
    required ScheduleChangeRequest request,
    required bool approve,
    required String adminNotes,
  }) async {
    if (!request.isPending) {
      return;
    }

    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final user = _ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        throw StateError('Not signed in');
      }

      if (approve) {
        final locationId = readScheduleField(
          request.requestedChanges,
          const ['locationId', 'selectedLocation'],
        );
        if (locationId.isNotEmpty) {
          await _ref
              .read(locationsRepositoryProvider)
              .ensureFighterAssignedToLocation(
                locationId: locationId,
                fighterId: request.fighterId,
              );
        }
      }

      await _ref.read(scheduleChangeRequestsRepositoryProvider).reviewRequest(
            requestId: request.id,
            approve: approve,
            adminNotes: adminNotes,
            reviewedBy: user.uid,
            request: request,
          );

      await _ref.read(scheduleChangeNotificationQueueProvider).queueResolution(
            request: request,
            approved: approve,
            adminNotes: adminNotes,
          );

      state = state.copyWith(
        isLoading: false,
        successMessage: approve ? 'Request approved.' : 'Request rejected.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not update this request. Please try again.',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final scheduleChangeRequestMutationControllerProvider = StateNotifierProvider<
    ScheduleChangeRequestMutationController,
    ScheduleChangeRequestMutationState>((ref) {
  return ScheduleChangeRequestMutationController(ref);
});
