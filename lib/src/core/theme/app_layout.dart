import 'package:flutter/widgets.dart';

class AppLayout {
  static double pagePadding(BuildContext context) => _scale(context, 20);
  static double sectionGap(BuildContext context) => _scale(context, 18);
  static double cardPadding(BuildContext context) => _scale(context, 16);
  static double smallGap(BuildContext context) => _scale(context, 8);
  static double mediumGap(BuildContext context) => _scale(context, 12);
  static double largeGap(BuildContext context) => _scale(context, 20);
  static double kpiCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 760) {
      return double.infinity;
    }
    if (width < 1200) {
      return 220;
    }
    return 240;
  }

  static double chartDonutSize(BuildContext context) =>
      _scale(context, 120).clamp(90, 140);

  static double chartLabelWidth(BuildContext context) =>
      _scale(context, 112).clamp(90, 130);

  static double chartValueWidth(BuildContext context) =>
      _scale(context, 26).clamp(24, 34);

  static double chartBarHeight(BuildContext context) =>
      _scale(context, 14).clamp(10, 16);

  static double _scale(BuildContext context, double base) {
    final width = MediaQuery.sizeOf(context).width;
    final factor = (width / 1280).clamp(0.8, 1.15);
    return base * factor;
  }
}
