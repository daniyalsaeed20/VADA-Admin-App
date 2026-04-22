import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/locations_repository.dart';
import '../domain/location_record.dart';

final locationsRepositoryProvider = Provider<LocationsRepository>((ref) {
  return LocationsRepository(ref.watch(firestoreProvider));
});

final locationsStreamProvider = StreamProvider<List<LocationRecord>>((ref) {
  return ref.watch(locationsRepositoryProvider).watchLocations();
});

class LocationMutationState {
  const LocationMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  LocationMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return LocationMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class LocationMutationController extends StateNotifier<LocationMutationState> {
  LocationMutationController(this._ref) : super(const LocationMutationState());

  final Ref _ref;

  Future<void> create({
    required String name,
    required String address,
    required String type,
    required List<String> assignedFighterIds,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(locationsRepositoryProvider).createLocation(
            name: name,
            address: address,
            type: type,
            assignedFighterIds: assignedFighterIds,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'locations.createSuccess',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'locations.unknownError',
      );
    }
  }

  Future<void> update({
    required String id,
    required String name,
    required String address,
    required String type,
    required List<String> assignedFighterIds,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(locationsRepositoryProvider).updateLocation(
            id: id,
            name: name,
            address: address,
            type: type,
            assignedFighterIds: assignedFighterIds,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'locations.updateSuccess',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'locations.unknownError',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final locationMutationControllerProvider =
    StateNotifierProvider<LocationMutationController, LocationMutationState>((
  ref,
) {
  return LocationMutationController(ref);
});
