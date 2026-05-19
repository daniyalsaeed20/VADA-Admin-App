import 'checkin_alert_tone_stub.dart'
    if (dart.library.html) 'checkin_alert_tone_web.dart' as impl;

/// Unlocks alert audio after login (required on web — browsers block autoplay).
Future<void> primeCheckinAlertTone() => impl.primeCheckinAlertTone();

/// Plays the fighter check-in alert tone.
Future<void> playCheckinAlertTone() => impl.playCheckinAlertTone();
