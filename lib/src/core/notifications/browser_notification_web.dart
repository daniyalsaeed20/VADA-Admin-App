import 'dart:js_interop';

import 'package:web/web.dart';

Future<bool> requestBrowserNotificationPermission() async {
  if (!window.isSecureContext) return false;
  final permission = await Notification.requestPermission().toDart;
  return permission.toString() == 'granted';
}

void showBrowserNotification({
  required String title,
  required String body,
}) {
  if (Notification.permission.toString() != 'granted') return;
  Notification(title, NotificationOptions(body: body));
}
