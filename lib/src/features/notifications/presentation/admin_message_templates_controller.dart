import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/admin_message_templates_repository.dart';
import '../domain/admin_message_template.dart';

final adminMessageTemplatesRepositoryProvider =
    Provider<AdminMessageTemplatesRepository>((ref) {
  return AdminMessageTemplatesRepository(ref.watch(firestoreProvider));
});

final adminMessageTemplatesStreamProvider =
    StreamProvider<List<AdminMessageTemplate>>((ref) {
  return ref.watch(adminMessageTemplatesRepositoryProvider).watchTemplates();
});

class AdminMessageTemplateMutationState {
  const AdminMessageTemplateMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  AdminMessageTemplateMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AdminMessageTemplateMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class AdminMessageTemplateMutationController
    extends StateNotifier<AdminMessageTemplateMutationState> {
  AdminMessageTemplateMutationController(this._ref)
      : super(const AdminMessageTemplateMutationState());

  final Ref _ref;

  Future<void> create({
    required String name,
    required String title,
    required String body,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(adminMessageTemplatesRepositoryProvider).create(
            name: name,
            title: title,
            body: body,
          );
      state = state.copyWith(isLoading: false, successMessage: 'Saved');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> update({
    required String id,
    required String name,
    required String title,
    required String body,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(adminMessageTemplatesRepositoryProvider).update(
            id: id,
            name: name,
            title: title,
            body: body,
          );
      state = state.copyWith(isLoading: false, successMessage: 'Updated');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> delete({required String id}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(adminMessageTemplatesRepositoryProvider).delete(id: id);
      state = state.copyWith(isLoading: false, successMessage: 'Deleted');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final adminMessageTemplateMutationControllerProvider = StateNotifierProvider<
    AdminMessageTemplateMutationController, AdminMessageTemplateMutationState>(
  (ref) => AdminMessageTemplateMutationController(ref),
);

