import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/notifications/local_notifications_service.dart';
import '../../settings/presentation/notification_settings_controller.dart';
import '../domain/fighter.dart';
import 'fighters_controller.dart';

/// Shows a live alert when a fighter creates their own account from the
/// mobile app. Fighters created by an admin (createdBySource == 'admin')
/// are intentionally skipped — this listener is only for self sign-ups.
class FighterSignupAlertListener extends ConsumerStatefulWidget {
  const FighterSignupAlertListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FighterSignupAlertListener> createState() =>
      _FighterSignupAlertListenerState();
}

class _FighterSignupAlertListenerState
    extends ConsumerState<FighterSignupAlertListener> {
  Set<String> _seenIds = {};
  bool _initialized = false;
  bool _dialogOpen = false;
  Fighter? _queuedFighter;

  @override
  Widget build(BuildContext context) {
    ref.listen(fightersStreamProvider, (previous, next) {
      next.whenData(_onFightersUpdated);
    });
    return widget.child;
  }

  void _onFightersUpdated(List<Fighter> fighters) {
    if (!_initialized) {
      _initialized = true;
      _seenIds = fighters.map((f) => f.uid).toSet();
      return;
    }

    final newSelfSignups = fighters
        .where((f) => !_seenIds.contains(f.uid))
        .where((f) => f.createdBySource != 'admin')
        .toList();
    _seenIds = fighters.map((f) => f.uid).toSet();

    if (newSelfSignups.isEmpty) return;

    if (!ref.read(notificationSettingsCurrentProvider).enableFighterSignupAlerts) {
      return;
    }

    if (_dialogOpen) {
      _queuedFighter = newSelfSignups.first;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showAlert(newSelfSignups.first);
    });
  }

  Future<void> _showAlert(Fighter fighter) async {
    if (!mounted || _dialogOpen) return;

    _dialogOpen = true;

    final fighterName = fighter.fullName.trim().isEmpty
        ? 'A fighter'
        : fighter.fullName.trim();
    const title = 'New fighter registration';
    final body = '$fighterName just created an account.';

    await LocalNotificationsService.instance.showFighterSignup(
      id: fighter.uid.hashCode.abs(),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                context.go(AppRoutes.fighters);
              }
            },
            child: const Text('View fighter'),
          ),
        ],
      ),
    );

    _dialogOpen = false;
    final queued = _queuedFighter;
    _queuedFighter = null;
    if (queued != null && mounted && queued.uid != fighter.uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAlert(queued);
      });
    }
  }
}
