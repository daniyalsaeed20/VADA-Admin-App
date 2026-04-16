import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/fighters_repository.dart';
import '../domain/fighter.dart';

final fightersRepositoryProvider = Provider<FightersRepository>((ref) {
  return FightersRepository(ref.watch(firestoreProvider));
});

final fightersStreamProvider = StreamProvider<List<Fighter>>((ref) {
  return ref.watch(fightersRepositoryProvider).watchFighters();
});

class FighterMutationState {
  const FighterMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  FighterMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return FighterMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class FighterMutationController extends StateNotifier<FighterMutationState> {
  FighterMutationController(this._ref) : super(const FighterMutationState());

  final Ref _ref;

  Future<void> create({
    required String fullName,
    required String dateOfBirth,
    required String gender,
    required String phone,
    required String email,
    required String address,
    required String primaryContactPerson,
    required String password,
    required bool disabled,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(fightersRepositoryProvider).createFighter(
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            gender: gender,
            phone: phone,
            email: email,
            address: address,
            primaryContactPerson: primaryContactPerson,
            password: password,
            disabled: disabled,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'fighters.createSuccess',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'fighters.unknownError',
      );
    }
  }

  Future<void> update({
    required String uid,
    required String fullName,
    required String dateOfBirth,
    required String gender,
    required String phone,
    required String email,
    required String address,
    required String primaryContactPerson,
    required bool disabled,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(fightersRepositoryProvider).updateFighter(
            uid: uid,
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            gender: gender,
            phone: phone,
            email: email,
            address: address,
            primaryContactPerson: primaryContactPerson,
            disabled: disabled,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'fighters.updateSuccess',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'fighters.unknownError',
      );
    }
  }

  Future<void> toggleAccess({
    required String uid,
    required bool disabled,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(fightersRepositoryProvider).setFighterAccess(
            uid: uid,
            disabled: disabled,
          );
      state = state.copyWith(isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'fighters.unknownError',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final fighterMutationControllerProvider =
    StateNotifierProvider<FighterMutationController, FighterMutationState>((ref) {
      return FighterMutationController(ref);
    });
