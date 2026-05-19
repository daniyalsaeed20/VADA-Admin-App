import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../schedule_change_requests/domain/schedule_change_request.dart';
import '../../settings/domain/notification_settings.dart';
import '../../settings/presentation/notification_settings_controller.dart';
import '../data/notifications_repository.dart';
import '../presentation/notifications_controller.dart';
import 'notification_context_resolver.dart';
import 'notification_message_composer.dart';

/// Queues fighter notifications when a schedule change request is approved or rejected.
class ScheduleChangeNotificationQueue {
  const ScheduleChangeNotificationQueue({
    required NotificationsRepository notifications,
    required NotificationContextResolver resolver,
    required NotificationSettings settings,
    required String createdBy,
  })  : _notifications = notifications,
        _resolver = resolver,
        _settings = settings,
        _createdBy = createdBy;

  final NotificationsRepository _notifications;
  final NotificationContextResolver _resolver;
  final NotificationSettings _settings;
  final String _createdBy;

  Future<void> queueResolution({
    required ScheduleChangeRequest request,
    required bool approved,
    required String adminNotes,
  }) async {
    if (!_settings.enableScheduleChangeReviews) {
      return;
    }

    final fighterName = await _resolver.fighterName(request.fighterId);
    final locationId = readScheduleField(
      request.requestedChanges,
      const ['locationId'],
    );
    final locationName = locationId.isEmpty
        ? ''
        : await _resolver.locationName(locationId);

    final placeholders =
        NotificationMessageComposer.placeholdersForScheduleChangeRequest(
      request: request,
      fighterName: fighterName,
      adminNotes: adminNotes,
      locationName: locationName,
    );

    final message = NotificationMessageComposer.composeScheduleChangeResolution(
      settings: _settings,
      approved: approved,
      values: placeholders,
    );

    await _notifications.createScheduleChangeResolution(
      title: message.title,
      body: message.body,
      fighterId: request.fighterId,
      requestId: request.id,
      scheduleId: request.scheduleId,
      createdBy: _createdBy,
    );
  }
}

final scheduleChangeNotificationQueueProvider =
    Provider<ScheduleChangeNotificationQueue>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  return ScheduleChangeNotificationQueue(
    notifications: ref.watch(notificationsRepositoryProvider),
    resolver: ref.watch(notificationContextResolverProvider),
    settings: ref.watch(notificationSettingsCurrentProvider),
    createdBy: user?.uid ?? '',
  );
});
