import 'package:flutter/material.dart';
import 'package:loglens/loglens.dart';

/// Light terminal palette for the floating log console.
class ConsoleTheme {
  ConsoleTheme._();
  static const Color shell = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E4E7);
  static const Color borderStrong = Color(0xFFD4D4D8);
  static const Color titleBar = Color(0xFFF4F4F5);
  static const Color textPrimary = Color(0xFF18181B);
  static const Color textSecondary = Color(0xFF71717A);
  static const Color textMuted = Color(0xFFA1A1AA);
  static const Color prompt = Color(0xFF3F3F46);
  static const Color selection = Color(0xFFF4F4F5);
  static const Color shadow = Color(0x1A000000);

  static const double radius = 10;
  static const double radiusSm = 6;
  static const double headerHeight = 38;
  static const double toolbarBtn = 28;

  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    height: 1.45,
    letterSpacing: 0.1,
  );

  static const TextStyle monoSm = TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    color: textSecondary,
  );

  static Color levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return const Color(0xFF71717A);
      case LogLevel.info:
        return const Color(0xFF2563EB);
      case LogLevel.warning:
        return const Color(0xFFD97706);
      case LogLevel.error:
        return const Color(0xFFDC2626);
    }
  }

  static Color levelBg(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return const Color(0xFFF4F4F5);
      case LogLevel.info:
        return const Color(0xFFEFF6FF);
      case LogLevel.warning:
        return const Color(0xFFFFFBEB);
      case LogLevel.error:
        return const Color(0xFFFEF2F2);
    }
  }

  static String levelLabel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DBG';
      case LogLevel.info:
        return 'INF';
      case LogLevel.warning:
        return 'WRN';
      case LogLevel.error:
        return 'ERR';
    }
  }
}
