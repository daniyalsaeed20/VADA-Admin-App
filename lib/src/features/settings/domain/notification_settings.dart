import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettings {
  const NotificationSettings({
    required this.enableAdminMessages,
    required this.enableScheduleUpdates,
    required this.scheduleUpdateTitleTemplate,
    required this.scheduleUpdateBodyTemplate,
    required this.updatedAt,
  });

  final bool enableAdminMessages;
  final bool enableScheduleUpdates;
  final String scheduleUpdateTitleTemplate;
  final String scheduleUpdateBodyTemplate;
  final DateTime? updatedAt;

  factory NotificationSettings.defaults() {
    return const NotificationSettings(
      enableAdminMessages: true,
      enableScheduleUpdates: true,
      scheduleUpdateTitleTemplate: '',
      scheduleUpdateBodyTemplate: '',
      updatedAt: null,
    );
  }

  factory NotificationSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return NotificationSettings(
      enableAdminMessages: (data['enableAdminMessages'] as bool?) ?? true,
      enableScheduleUpdates: (data['enableScheduleUpdates'] as bool?) ?? true,
      scheduleUpdateTitleTemplate:
          (data['scheduleUpdateTitleTemplate'] as String? ?? '').trim(),
      scheduleUpdateBodyTemplate:
          (data['scheduleUpdateBodyTemplate'] as String? ?? '').trim(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enableAdminMessages': enableAdminMessages,
      'enableScheduleUpdates': enableScheduleUpdates,
      'scheduleUpdateTitleTemplate': scheduleUpdateTitleTemplate.trim(),
      'scheduleUpdateBodyTemplate': scheduleUpdateBodyTemplate.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  NotificationSettings copyWith({
    bool? enableAdminMessages,
    bool? enableScheduleUpdates,
    String? scheduleUpdateTitleTemplate,
    String? scheduleUpdateBodyTemplate,
  }) {
    return NotificationSettings(
      enableAdminMessages: enableAdminMessages ?? this.enableAdminMessages,
      enableScheduleUpdates: enableScheduleUpdates ?? this.enableScheduleUpdates,
      scheduleUpdateTitleTemplate:
          scheduleUpdateTitleTemplate ?? this.scheduleUpdateTitleTemplate,
      scheduleUpdateBodyTemplate:
          scheduleUpdateBodyTemplate ?? this.scheduleUpdateBodyTemplate,
      updatedAt: updatedAt,
    );
  }
}

