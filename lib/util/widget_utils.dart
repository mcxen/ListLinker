import 'package:flutter/material.dart';

class WidgetUtils {
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Bottom inset matching the system navigation bar for list content padding.
  static double listBottomInset(
    BuildContext context, {
    double minimum = 16,
  }) {
    final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    return viewPadding > minimum ? viewPadding : minimum;
  }

  static EdgeInsets listViewPadding(
    BuildContext context, {
    double extraBottom = 0,
  }) {
    return EdgeInsets.only(
      bottom: listBottomInset(context) + extraBottom,
    );
  }
}
