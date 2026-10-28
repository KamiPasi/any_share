import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 新界面的配色，取值和设计稿保持一致
class AppUi {
  AppUi._();

  static const Color accent = Color(0xff5b5bd6);
  static const Color accentSoft = Color(0xffefeffb);
  static const Color accentLine = Color(0xffcecef3);
  static const Color accentText = Color(0xff4444a1);

  static const Color background = Color(0xfff4f5f7);
  static const Color surface = Color(0xffffffff);
  static const Color surfaceMuted = Color(0xfffafafb);
  static const Color subtle = Color(0xfff1f2f5);
  static const Color segment = Color(0xffe9ebef);
  static const Color field = Color(0xfff6f7f9);
  static const Color border = Color(0xffe5e7eb);
  static const Color borderStrong = Color(0xffd6d9df);
  static const Color divider = Color(0xffeef0f3);

  static const Color text = Color(0xff1f2328);
  static const Color textSecondary = Color(0xff5b6270);
  static const Color textMuted = Color(0xff3d4350);
  static const Color placeholder = Color(0xff6b7280);

  static const Color online = Color(0xff16a34a);
  static const Color onlineText = Color(0xff15803d);
  static const Color offline = Color(0xffb8bdc6);

  static const Color warningBackground = Color(0xfffff7e8);
  static const Color warningBorder = Color(0xfff3d9a4);
  static const Color warningIcon = Color(0xffb45309);
  static const Color warningText = Color(0xff7c4a03);

  /// 显示 IP 地址、路径用的等宽字体
  static TextStyle mono({double fontSize = 13, Color color = AppUi.text}) {
    return TextStyle(
      fontFamily: defaultTargetPlatform == TargetPlatform.windows ? 'Consolas' : 'monospace',
      fontSize: fontSize,
      color: color,
    );
  }
}
