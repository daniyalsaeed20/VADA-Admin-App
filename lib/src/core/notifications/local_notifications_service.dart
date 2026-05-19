import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'browser_notification.dart'
    if (dart.library.html) 'browser_notification_web.dart' as browser;

/// OS / browser notifications for admin alerts.
class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const initSettings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Call after a user gesture (e.g. login) so browsers allow notifications.
  Future<void> requestPermissions() async {
    if (!_initialized) await initialize();

    if (kIsWeb) {
      await browser.requestBrowserNotificationPermission();
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showFighterCheckin({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    if (kIsWeb) {
      browser.showBrowserNotification(title: title, body: body);
      return;
    }

    const android = AndroidNotificationDetails(
      'fighter_checkins',
      'Fighter check-ins',
      channelDescription: 'Alerts when a fighter checks in',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    try {
      await _plugin.show(id, title, body, details);
    } catch (_) {
      // Permission denied — dialog still shows.
    }
  }
}
