import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart';

const _assetPath = 'assets/sounds/checkin_alert.wav';

HTMLAudioElement? _alertAudio;
String? _objectUrl;

Future<HTMLAudioElement> _loadAlertAudio() async {
  if (_alertAudio != null) return _alertAudio!;

  final data = await rootBundle.load(_assetPath);
  final bytes = data.buffer.asUint8List();
  final blob = Blob(<BlobPart>[bytes.toJS].toJS);
  _objectUrl = URL.createObjectURL(blob);

  _alertAudio = HTMLAudioElement()
    ..src = _objectUrl!
    ..volume = 1.0
    ..preload = 'auto';

  return _alertAudio!;
}

/// Call once after a user gesture (login) so later check-in alerts can play sound.
Future<void> primeCheckinAlertTone() async {
  try {
    final audio = await _loadAlertAudio();
    audio.volume = 0.01;
    await audio.play().toDart;
    audio.pause();
    audio.currentTime = 0;
    audio.volume = 1.0;
  } catch (_) {
    // Browser may still block until further interaction.
  }
}

Future<void> playCheckinAlertTone() async {
  try {
    final audio = await _loadAlertAudio();
    audio.pause();
    audio.currentTime = 0;
    audio.volume = 1.0;
    await audio.play().toDart;
  } catch (_) {
    // Firestore updates are not a user gesture; login prime must run first.
  }
}
