import 'dart:ui';
import 'assets.dart';
import 'device_type.dart';

extension DeviceTypeExt on DeviceType {
  String get iconPath {
    switch (this) {
      case DeviceType.android:
        return SvgAssets.androidLogo;
      case DeviceType.ios:
        return SvgAssets.iosLogo;
      case DeviceType.mac:
      case DeviceType.windows:
      case DeviceType.linux:
      case DeviceType.browser:
      default:
        return SvgAssets.desktop;
    }
  }

  Color get deviceColor {
    switch (this) {
      case DeviceType.android:
        return Color(TailwindColor.orange700.value);
      case DeviceType.ios:
        return Color(TailwindColor.teal700.value);
      case DeviceType.mac:
        return Color(TailwindColor.indigo700.value);
      case DeviceType.windows:
        return Color(TailwindColor.blue700.value);
      case DeviceType.linux:
        return Color(TailwindColor.purple700.value);
      case DeviceType.browser:
        return Color(TailwindColor.pink700.value);
      default:
        // 识别不了的设备类型（比如旧版协议里的其他编号）也要能显示消息
        return Color(TailwindColor.green700.value);
    }
  }
}

enum TailwindColor {
  red700(0xffC53030),
  orange700(0xffC05621),
  teal700(0xff2C7A7B),
  blue700(0xff2B6CB0),
  indigo700(0xff4C51BF),
  purple700(0xff6B46C1),
  pink700(0xffB83280),
  green700(0xff2F855A);

  const TailwindColor(this.value);

  final int value;
}
