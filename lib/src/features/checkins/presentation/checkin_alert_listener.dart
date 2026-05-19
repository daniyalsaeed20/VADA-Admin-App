import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/checkin_alert_tone.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/notifications/local_notifications_service.dart';
import '../../../core/localization/localization_x.dart';
import '../../fighters/presentation/fighters_controller.dart';
import '../../settings/presentation/notification_settings_controller.dart';
import '../domain/checkin_record.dart';
import 'checkins_controller.dart';
import 'widgets/fighter_checkin_alert_dialog.dart';

/// Shows a modal alert with sound when a new fighter check-in appears.
class CheckinAlertListener extends ConsumerStatefulWidget {
  const CheckinAlertListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CheckinAlertListener> createState() =>
      _CheckinAlertListenerState();
}

class _CheckinAlertListenerState extends ConsumerState<CheckinAlertListener> {
  String? _latestSeenId;
  bool _initialized = false;
  bool _dialogOpen = false;
  CheckinRecord? _queuedRecord;

  @override
  Widget build(BuildContext context) {
    ref.listen(checkinsStreamProvider, (previous, next) {
      next.whenData(_onCheckinsUpdated);
    });
    return widget.child;
  }

  void _onCheckinsUpdated(List<CheckinRecord> checkins) {
    if (checkins.isEmpty) return;

    final latest = checkins.first;
    if (!_initialized) {
      _initialized = true;
      _latestSeenId = latest.id;
      return;
    }

    if (_latestSeenId == latest.id) return;
    _latestSeenId = latest.id;

    if (!ref.read(notificationSettingsCurrentProvider).enableFighterCheckinAlerts) {
      return;
    }

    if (_dialogOpen) {
      _queuedRecord = latest;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showAlert(latest);
    });
  }

  Future<void> _showAlert(CheckinRecord record) async {
    if (!mounted || _dialogOpen) return;

    _dialogOpen = true;

    final loc = context.l10n;
    final fighterName = _fighterNameFor(record.fighterId);
    final captured = record.capturedAt ?? record.createdAt;
    final timeLabel = captured != null ? _formatDateTime(captured) : '';
    final title = loc.tr('checkins.alertTitle');
    final body = loc
        .tr('checkins.alertBody')
        .replaceAll('{fighterName}', fighterName)
        .replaceAll('{time}', timeLabel);

    await playCheckinAlertTone();
    await LocalNotificationsService.instance.showFighterCheckin(
      id: record.id.hashCode.abs(),
      title: title,
      body: body,
    );

    if (!mounted) {
      _dialogOpen = false;
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => FighterCheckinAlertDialog(
        fighterName: fighterName,
        record: record,
        timeLabel: timeLabel,
        titleText: title,
        dismissLabel: loc.tr('checkins.alertDismiss'),
        viewLabel: loc.tr('checkins.alertView'),
        timeCaption: loc.tr('checkins.alertTime'),
        accuracyCaption: loc.tr('checkins.alertAccuracy'),
        labelCaption: loc.tr('checkins.alertLabel'),
        onView: () {
          if (context.mounted) {
            context.go(AppRoutes.checkins);
          }
        },
      ),
    );

    _dialogOpen = false;
    final queued = _queuedRecord;
    _queuedRecord = null;
    if (queued != null && mounted && queued.id != record.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAlert(queued);
      });
    }
  }

  String _fighterNameFor(String fighterId) {
    final fighters = ref.read(fightersStreamProvider).asData?.value ?? const [];
    return fighters
            .where((f) => f.uid == fighterId)
            .map((f) => f.fullName)
            .where((n) => n.trim().isNotEmpty)
            .firstOrNull ??
        fighterId;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
