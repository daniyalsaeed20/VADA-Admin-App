import 'package:flutter/services.dart';

Future<void> primeCheckinAlertTone() async {}

Future<void> playCheckinAlertTone() async {
  try {
    await SystemSound.play(SystemSoundType.alert);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await SystemSound.play(SystemSoundType.alert);
  } catch (_) {}
}
