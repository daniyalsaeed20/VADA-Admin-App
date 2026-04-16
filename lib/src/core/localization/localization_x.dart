import 'package:flutter/material.dart';

import 'app_localizations.dart';

extension LocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations(Localizations.localeOf(this));
}
