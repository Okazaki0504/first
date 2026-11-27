import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// RPG風の配色（モックと同じ）
class C {
  static const night = Color(0xFF141A33);
  static const panel = Color(0xFF1F2850);
  static const panel2 = Color(0xFF2A3466);
  static const deep = Color(0xFF0F1430);
  static const deeper = Color(0xFF0C1024);
  static const line = Color(0xFFE9E4CF);
  static const edge = Color(0xFF4A5590);
  static const ink = Color(0xFFF3EFE0);
  static const muted = Color(0xFFA7ADD0);
  static const gold = Color(0xFFF2C14E);
  static const goldDark = Color(0xFFA37C1F);
  static const hp = Color(0xFFFF6B6B);
  static const mp = Color(0xFF5EC8F2);
  static const ok = Color(0xFF7EE08A);
}

const pixelFont = 'DotGothic16';
const bodyFont = 'MPLUS1p';

TextStyle px(double size, {Color color = C.ink}) => TextStyle(fontFamily: pixelFont, fontSize: size, color: color, height: 1.4);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: bodyFont);
  return base.copyWith(
    scaffoldBackgroundColor: C.night,
    colorScheme: base.colorScheme.copyWith(primary: C.gold, secondary: C.mp, surface: C.panel, onPrimary: C.night),
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink, fontFamily: bodyFont),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.night : C.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.gold : C.deep),
    ),
  );
}

/// 振動（設定でオフにできる）
class Haptics {
  static bool enabled = true;
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void big() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void wrong() {
    if (enabled) HapticFeedback.vibrate();
  }
}
