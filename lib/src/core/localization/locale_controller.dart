import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
      return LocaleController();
    });

class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(const Locale('en'));

  void setLocale(Locale locale) {
    state = locale;
  }
}
