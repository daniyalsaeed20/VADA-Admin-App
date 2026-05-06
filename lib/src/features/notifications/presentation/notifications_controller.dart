import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/notifications_repository.dart';
import '../domain/admin_message_request.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(firestoreProvider));
});

final adminMessagesStreamProvider =
    StreamProvider<List<AdminMessageRequest>>((ref) {
  return ref.watch(notificationsRepositoryProvider).watchAdminMessages();
});

class AdminMessageMutationState {
  const AdminMessageMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  AdminMessageMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AdminMessageMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class AdminMessageMutationController
    extends StateNotifier<AdminMessageMutationState> {
  AdminMessageMutationController(this._ref)
      : super(const AdminMessageMutationState());

  final Ref _ref;

  Future<void> send({
    required String title,
    required String body,
    required String target, // broadcast | user
    String? targetUserId,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final auth = _ref.read(firebaseAuthProvider);
      final user = auth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Not signed in');
        return;
      }
      await _ref.read(notificationsRepositoryProvider).createAdminMessage(
            title: title,
            body: body,
            target: target,
            targetUserId: targetUserId,
            createdBy: user.uid,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Notification queued',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final adminMessageMutationControllerProvider = StateNotifierProvider<
    AdminMessageMutationController, AdminMessageMutationState>((ref) {
  return AdminMessageMutationController(ref);
});

