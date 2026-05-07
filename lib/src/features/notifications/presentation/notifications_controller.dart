import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../data/notifications_repository.dart';
import '../domain/admin_message_request.dart';
import '../../settings/presentation/notification_settings_controller.dart';

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

  String _fmtDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<String?> _readFighterName(String uid) async {
    if (uid.trim().isEmpty) return null;
    try {
      final snap = await _ref
          .read(firestoreProvider)
          .collection(FirestoreCollections.users)
          .doc(uid.trim())
          .get();
      final data = snap.data();
      if (data == null) return null;
      const keys = ['fullName', 'name', 'displayName', 'full_name'];
      for (final k in keys) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) {
          return v.trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _placeholderValues({
    required String target,
    required String targetUserId,
  }) async {
    final now = DateTime.now();
    return {
      // {fighterName} is intentionally NOT resolved for broadcast here.
      // Broadcast personalization is handled in Cloud Functions per-recipient.
      '{date}': _fmtDate(now),
      '{time}': _fmtTime(now),
      '{datetime}': '${_fmtDate(now)} ${_fmtTime(now)}',
    };
  }

  Future<String> _applyPlaceholders(
    String input, {
    required String target,
    required String targetUserId,
  }) async {
    var out = input;

    // Resolve fighterName only for user-target notifications.
    if (target == 'user') {
      final fighterName =
          (await _readFighterName(targetUserId)) ??
          (targetUserId.trim().isEmpty ? 'Fighter' : targetUserId.trim());
      out = out.replaceAll('{fighterName}', fighterName);
    }

    final map = await _placeholderValues(
      target: target,
      targetUserId: targetUserId,
    );
    for (final entry in map.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }

  Future<void> send({
    required String title,
    required String body,
    required String target, // broadcast | user
    String? targetUserId,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final settings = _ref.read(notificationSettingsCurrentProvider);
      if (!settings.enableAdminMessages) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Admin messages are disabled in Settings.',
        );
        return;
      }
      final auth = _ref.read(firebaseAuthProvider);
      final user = auth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Not signed in');
        return;
      }
      final resolvedTitle = await _applyPlaceholders(
        title,
        target: target,
        targetUserId: targetUserId ?? '',
      );
      final resolvedBody = await _applyPlaceholders(
        body,
        target: target,
        targetUserId: targetUserId ?? '',
      );
      await _ref.read(notificationsRepositoryProvider).createAdminMessage(
            title: resolvedTitle,
            body: resolvedBody,
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

