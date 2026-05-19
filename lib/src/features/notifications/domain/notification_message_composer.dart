import '../../../core/notifications/notification_templates.dart';
import '../../schedule_change_requests/domain/schedule_change_approve_helpers.dart';
import '../../schedule_change_requests/domain/schedule_change_request.dart';
import '../../settings/domain/notification_settings.dart';
import '../../whereabouts/domain/whereabouts_entry.dart';

class NotificationMessage {
  const NotificationMessage({required this.title, required this.body});

  final String title;
  final String body;
}

class NotificationMessageComposer {
  const NotificationMessageComposer._();

  static const defaultScheduleUpdateTitle =
      'Schedule updated • {fighterName}';
  static const defaultScheduleUpdateBody =
      '{date} • {startTime}-{endTime}\n'
      'Location: {locationName}\n'
      'Contact: {contactName}\n'
      'Repeat: {recurrence}\n'
      '{notes}';

  static const defaultScheduleChangeApprovedTitle =
      'Schedule change approved • {fighterName}';
  static const defaultScheduleChangeApprovedBody =
      'Your {requestType} request was approved.\n'
      '{adminNotes}';

  static const defaultScheduleChangeRejectedTitle =
      'Schedule change rejected • {fighterName}';
  static const defaultScheduleChangeRejectedBody =
      'Your {requestType} request was rejected.\n'
      '{adminNotes}';

  static NotificationMessage composeScheduleUpdate({
    required NotificationSettings settings,
    required String fighterName,
    required String date,
    required String startTime,
    required String endTime,
    required String locationName,
    required String contactName,
    required String recurrence,
    required String notes,
    required bool isCreate,
  }) {
    final notesPreview = notes.trim().isEmpty
        ? ''
        : (notes.trim().length <= 80
            ? notes.trim()
            : '${notes.trim().substring(0, 80)}…');

    final defaultTitle = isCreate
        ? 'Schedule created • $fighterName'
        : 'Schedule updated • $fighterName';

    final bodyLines = <String>[
      '$date • $startTime-$endTime',
      'Location: $locationName',
      'Contact: $contactName',
      'Repeat: ${normalizeRecurrence(recurrence)}',
      if (notesPreview.isNotEmpty) 'Notes: $notesPreview',
    ];
    final defaultBody = bodyLines.join('\n');

    final values = <String, String>{
      'fighterName': fighterName,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'locationName': locationName,
      'contactName': contactName,
      'recurrence': normalizeRecurrence(recurrence),
      'notes': notes.trim(),
    };

    return NotificationMessage(
      title: applyNotificationTemplate(
        template: settings.scheduleUpdateTitleTemplate,
        values: values,
        fallback: applyNotificationTemplate(
          template: defaultScheduleUpdateTitle,
          values: values,
          fallback: defaultTitle,
        ),
      ),
      body: applyNotificationTemplate(
        template: settings.scheduleUpdateBodyTemplate,
        values: values,
        fallback: applyNotificationTemplate(
          template: defaultScheduleUpdateBody,
          values: values,
          fallback: defaultBody,
        ),
      ),
    );
  }

  static NotificationMessage composeScheduleChangeResolution({
    required NotificationSettings settings,
    required bool approved,
    required Map<String, String> values,
  }) {
    final adminNotes = values['adminNotes']?.trim() ?? '';
    final requestType = values['requestType']?.trim() ?? 'schedule change';
    final fighterName = values['fighterName']?.trim() ?? 'Fighter';

    final defaultTitle = approved
        ? 'Schedule change approved • $fighterName'
        : 'Schedule change rejected • $fighterName';

    final defaultBody = approved
        ? _defaultApprovedBody(requestType: requestType, adminNotes: adminNotes)
        : _defaultRejectedBody(requestType: requestType, adminNotes: adminNotes);

    if (approved) {
      return NotificationMessage(
        title: applyNotificationTemplate(
          template: settings.scheduleChangeApprovedTitleTemplate,
          values: values,
          fallback: applyNotificationTemplate(
            template: defaultScheduleChangeApprovedTitle,
            values: values,
            fallback: defaultTitle,
          ),
        ),
        body: applyNotificationTemplate(
          template: settings.scheduleChangeApprovedBodyTemplate,
          values: values,
          fallback: applyNotificationTemplate(
            template: defaultScheduleChangeApprovedBody,
            values: values,
            fallback: defaultBody,
          ),
        ),
      );
    }

    return NotificationMessage(
      title: applyNotificationTemplate(
        template: settings.scheduleChangeRejectedTitleTemplate,
        values: values,
        fallback: applyNotificationTemplate(
          template: defaultScheduleChangeRejectedTitle,
          values: values,
          fallback: defaultTitle,
        ),
      ),
      body: applyNotificationTemplate(
        template: settings.scheduleChangeRejectedBodyTemplate,
        values: values,
        fallback: applyNotificationTemplate(
          template: defaultScheduleChangeRejectedBody,
          values: values,
          fallback: defaultBody,
        ),
      ),
    );
  }

  static Map<String, String> placeholdersForScheduleChangeRequest({
    required ScheduleChangeRequest request,
    required String fighterName,
    required String adminNotes,
    String locationName = '',
    Map<String, dynamic>? requestedChangesOverride,
  }) {
    final changes = requestedChangesOverride ?? request.requestedChanges;
    final snapshot = request.currentSnapshot;

    String field(List<String> keys) {
      final fromChanges = readScheduleField(changes, keys);
      if (fromChanges.isNotEmpty) {
        return fromChanges;
      }
      return readScheduleField(snapshot, keys);
    }

    final proposed = readScheduleField(changes, const ['proposedLocationText']);
    final proposedOut = proposed.isNotEmpty
        ? proposed
        : readRequestedNewSiteSummary(changes);

    final loc = locationName.isNotEmpty
        ? locationName
        : readRequestedNewSiteName(changes);

    return {
      'fighterName': fighterName,
      'requestType': request.requestTypeLabel,
      'adminNotes': adminNotes.trim(),
      'date': field(const ['date', 'scheduleDate']),
      'startTime': field(const ['startTime', 'fromTime']),
      'endTime': field(const ['endTime', 'toTime']),
      'locationName': loc,
      'locationAddress': readRequestedNewSiteAddress(changes),
      'proposedLocationText': proposedOut,
    };
  }

  static String _defaultApprovedBody({
    required String requestType,
    required String adminNotes,
  }) {
    if (adminNotes.isNotEmpty) {
      return 'Your $requestType request was approved.\n$adminNotes';
    }
    return 'Your $requestType request was approved. '
        'Your schedule has been updated where applicable.';
  }

  static String _defaultRejectedBody({
    required String requestType,
    required String adminNotes,
  }) {
    if (adminNotes.isNotEmpty) {
      return 'Your $requestType request was rejected.\n$adminNotes';
    }
    return 'Your $requestType request was rejected. '
        'Please contact your administrator if you have questions.';
  }
}
