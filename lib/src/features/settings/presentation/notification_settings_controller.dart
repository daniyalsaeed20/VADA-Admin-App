import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/settings_repository.dart';
import '../domain/notification_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(firestoreProvider));
});

final notificationSettingsStreamProvider =
    StreamProvider<NotificationSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchNotificationSettings();
});

/// Best-effort "current" settings (uses defaults while loading).
final notificationSettingsCurrentProvider = Provider<NotificationSettings>((ref) {
  final async = ref.watch(notificationSettingsStreamProvider);
  return async.asData?.value ?? NotificationSettings.defaults();
});

final notificationSettingsProvider = FutureProvider<NotificationSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).getNotificationSettings();
});

class NotificationSettingsMutationState {
  const NotificationSettingsMutationState({
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  NotificationSettingsMutationState copyWith({
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return NotificationSettingsMutationState(
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class NotificationSettingsMutationController
    extends StateNotifier<NotificationSettingsMutationState> {
  NotificationSettingsMutationController(this._ref)
      : super(const NotificationSettingsMutationState());

  final Ref _ref;

  Future<void> save(NotificationSettings next) async {
    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(settingsRepositoryProvider).updateNotificationSettings(next);
      _ref.invalidate(notificationSettingsProvider);
      state = state.copyWith(isSaving: false, successMessage: 'Saved');
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final notificationSettingsMutationControllerProvider = StateNotifierProvider<
    NotificationSettingsMutationController, NotificationSettingsMutationState>(
  (ref) => NotificationSettingsMutationController(ref),
);

