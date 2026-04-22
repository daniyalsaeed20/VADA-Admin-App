import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/whereabouts_repository.dart';
import '../domain/whereabouts_entry.dart';

final whereaboutsRepositoryProvider = Provider<WhereaboutsRepository>((ref) {
  return WhereaboutsRepository(ref.watch(firestoreProvider));
});

final whereaboutsStreamProvider = StreamProvider<List<WhereaboutsEntry>>((ref) {
  return ref.watch(whereaboutsRepositoryProvider).watchWhereabouts();
});

class WhereaboutsMutationState {
  const WhereaboutsMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  WhereaboutsMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return WhereaboutsMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class WhereaboutsMutationController
    extends StateNotifier<WhereaboutsMutationState> {
  WhereaboutsMutationController(this._ref)
      : super(const WhereaboutsMutationState());

  final Ref _ref;

  Future<void> create({
    required String fighterId,
    required String date,
    required String startTime,
    required String endTime,
    required String locationId,
    required String contactId,
    required String notes,
    required String recurrence,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(whereaboutsRepositoryProvider).createWhereabouts(
            fighterId: fighterId,
            date: date,
            startTime: startTime,
            endTime: endTime,
            locationId: locationId,
            contactId: contactId,
            notes: notes,
            recurrence: recurrence,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'whereabouts.createSuccess',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'whereabouts.unknownError',
      );
    }
  }

  Future<void> update({
    required String id,
    required String fighterId,
    required String date,
    required String startTime,
    required String endTime,
    required String locationId,
    required String contactId,
    required String notes,
    required String recurrence,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(whereaboutsRepositoryProvider).updateWhereabouts(
            id: id,
            fighterId: fighterId,
            date: date,
            startTime: startTime,
            endTime: endTime,
            locationId: locationId,
            contactId: contactId,
            notes: notes,
            recurrence: recurrence,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'whereabouts.updateSuccess',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'whereabouts.unknownError',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final whereaboutsMutationControllerProvider = StateNotifierProvider<
    WhereaboutsMutationController, WhereaboutsMutationState>((ref) {
  return WhereaboutsMutationController(ref);
});
