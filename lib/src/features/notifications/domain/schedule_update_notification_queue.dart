import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../settings/domain/notification_settings.dart';
import '../../settings/presentation/notification_settings_controller.dart';
import '../data/notifications_repository.dart';
import '../presentation/notifications_controller.dart';
import 'notification_context_resolver.dart';
import 'notification_message_composer.dart';

/// Queues fighter notifications when admin creates or edits a schedule entry.
class ScheduleUpdateNotificationQueue {
  const ScheduleUpdateNotificationQueue({
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

  Future<void> queueScheduleChange({
    required String fighterId,
    required String scheduleId,
    required String date,
    required String startTime,
    required String endTime,
    required String locationId,
    required String contactId,
    required String recurrence,
    required String notes,
    required bool isCreate,
  }) async {
    if (!_settings.enableScheduleUpdates) {
      return;
    }

    final fighterName = await _resolver.fighterName(fighterId);
    final locationName = await _resolver.locationName(locationId);
    final contactName = await _resolver.contactName(contactId);

    final message = NotificationMessageComposer.composeScheduleUpdate(
      settings: _settings,
      fighterName: fighterName,
      date: date,
      startTime: startTime,
      endTime: endTime,
      locationName: locationName,
      contactName: contactName,
      recurrence: recurrence,
      notes: notes,
      isCreate: isCreate,
    );

    await _notifications.createScheduleUpdate(
      title: message.title,
      body: message.body,
      fighterId: fighterId,
      scheduleId: scheduleId,
      createdBy: _createdBy,
    );
  }
}

final scheduleUpdateNotificationQueueProvider =
    Provider<ScheduleUpdateNotificationQueue>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  return ScheduleUpdateNotificationQueue(
    notifications: ref.watch(notificationsRepositoryProvider),
    resolver: ref.watch(notificationContextResolverProvider),
    settings: ref.watch(notificationSettingsCurrentProvider),
    createdBy: user?.uid ?? '',
  );
});
