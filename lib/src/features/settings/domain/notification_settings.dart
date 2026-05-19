import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettings {
  const NotificationSettings({
    required this.enableAdminMessages,
    required this.enableScheduleUpdates,
    required this.scheduleUpdateTitleTemplate,
    required this.scheduleUpdateBodyTemplate,
    required this.enableScheduleChangeReviews,
    required this.scheduleChangeApprovedTitleTemplate,
    required this.scheduleChangeApprovedBodyTemplate,
    required this.scheduleChangeRejectedTitleTemplate,
    required this.scheduleChangeRejectedBodyTemplate,
    required this.enableFighterCheckinAlerts,
    required this.fighterCheckinTitleTemplate,
    required this.fighterCheckinBodyTemplate,
    required this.updatedAt,
  });

  final bool enableAdminMessages;
  final bool enableScheduleUpdates;
  final String scheduleUpdateTitleTemplate;
  final String scheduleUpdateBodyTemplate;
  final bool enableScheduleChangeReviews;
  final String scheduleChangeApprovedTitleTemplate;
  final String scheduleChangeApprovedBodyTemplate;
  final String scheduleChangeRejectedTitleTemplate;
  final String scheduleChangeRejectedBodyTemplate;
  final bool enableFighterCheckinAlerts;
  final String fighterCheckinTitleTemplate;
  final String fighterCheckinBodyTemplate;
  final DateTime? updatedAt;

  factory NotificationSettings.defaults() {
    return const NotificationSettings(
      enableAdminMessages: true,
      enableScheduleUpdates: true,
      scheduleUpdateTitleTemplate: '',
      scheduleUpdateBodyTemplate: '',
      enableScheduleChangeReviews: true,
      scheduleChangeApprovedTitleTemplate: '',
      scheduleChangeApprovedBodyTemplate: '',
      scheduleChangeRejectedTitleTemplate: '',
      scheduleChangeRejectedBodyTemplate: '',
      enableFighterCheckinAlerts: true,
      fighterCheckinTitleTemplate: '',
      fighterCheckinBodyTemplate: '',
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
      enableScheduleChangeReviews:
          (data['enableScheduleChangeReviews'] as bool?) ?? true,
      scheduleChangeApprovedTitleTemplate:
          (data['scheduleChangeApprovedTitleTemplate'] as String? ?? '').trim(),
      scheduleChangeApprovedBodyTemplate:
          (data['scheduleChangeApprovedBodyTemplate'] as String? ?? '').trim(),
      scheduleChangeRejectedTitleTemplate:
          (data['scheduleChangeRejectedTitleTemplate'] as String? ?? '').trim(),
      scheduleChangeRejectedBodyTemplate:
          (data['scheduleChangeRejectedBodyTemplate'] as String? ?? '').trim(),
      enableFighterCheckinAlerts:
          (data['enableFighterCheckinAlerts'] as bool?) ?? true,
      fighterCheckinTitleTemplate:
          (data['fighterCheckinTitleTemplate'] as String? ?? '').trim(),
      fighterCheckinBodyTemplate:
          (data['fighterCheckinBodyTemplate'] as String? ?? '').trim(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enableAdminMessages': enableAdminMessages,
      'enableScheduleUpdates': enableScheduleUpdates,
      'scheduleUpdateTitleTemplate': scheduleUpdateTitleTemplate.trim(),
      'scheduleUpdateBodyTemplate': scheduleUpdateBodyTemplate.trim(),
      'enableScheduleChangeReviews': enableScheduleChangeReviews,
      'scheduleChangeApprovedTitleTemplate':
          scheduleChangeApprovedTitleTemplate.trim(),
      'scheduleChangeApprovedBodyTemplate':
          scheduleChangeApprovedBodyTemplate.trim(),
      'scheduleChangeRejectedTitleTemplate':
          scheduleChangeRejectedTitleTemplate.trim(),
      'scheduleChangeRejectedBodyTemplate':
          scheduleChangeRejectedBodyTemplate.trim(),
      'enableFighterCheckinAlerts': enableFighterCheckinAlerts,
      'fighterCheckinTitleTemplate': fighterCheckinTitleTemplate.trim(),
      'fighterCheckinBodyTemplate': fighterCheckinBodyTemplate.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  NotificationSettings copyWith({
    bool? enableAdminMessages,
    bool? enableScheduleUpdates,
    String? scheduleUpdateTitleTemplate,
    String? scheduleUpdateBodyTemplate,
    bool? enableScheduleChangeReviews,
    String? scheduleChangeApprovedTitleTemplate,
    String? scheduleChangeApprovedBodyTemplate,
    String? scheduleChangeRejectedTitleTemplate,
    String? scheduleChangeRejectedBodyTemplate,
    bool? enableFighterCheckinAlerts,
    String? fighterCheckinTitleTemplate,
    String? fighterCheckinBodyTemplate,
  }) {
    return NotificationSettings(
      enableAdminMessages: enableAdminMessages ?? this.enableAdminMessages,
      enableScheduleUpdates: enableScheduleUpdates ?? this.enableScheduleUpdates,
      scheduleUpdateTitleTemplate:
          scheduleUpdateTitleTemplate ?? this.scheduleUpdateTitleTemplate,
      scheduleUpdateBodyTemplate:
          scheduleUpdateBodyTemplate ?? this.scheduleUpdateBodyTemplate,
      enableScheduleChangeReviews:
          enableScheduleChangeReviews ?? this.enableScheduleChangeReviews,
      scheduleChangeApprovedTitleTemplate: scheduleChangeApprovedTitleTemplate ??
          this.scheduleChangeApprovedTitleTemplate,
      scheduleChangeApprovedBodyTemplate: scheduleChangeApprovedBodyTemplate ??
          this.scheduleChangeApprovedBodyTemplate,
      scheduleChangeRejectedTitleTemplate: scheduleChangeRejectedTitleTemplate ??
          this.scheduleChangeRejectedTitleTemplate,
      scheduleChangeRejectedBodyTemplate: scheduleChangeRejectedBodyTemplate ??
          this.scheduleChangeRejectedBodyTemplate,
      enableFighterCheckinAlerts:
          enableFighterCheckinAlerts ?? this.enableFighterCheckinAlerts,
      fighterCheckinTitleTemplate:
          fighterCheckinTitleTemplate ?? this.fighterCheckinTitleTemplate,
      fighterCheckinBodyTemplate:
          fighterCheckinBodyTemplate ?? this.fighterCheckinBodyTemplate,
      updatedAt: updatedAt,
    );
  }
}

