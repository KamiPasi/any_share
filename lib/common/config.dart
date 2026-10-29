import 'package:package_info_plus/package_info_plus.dart';

class Config {
  Config._();
  // 下面两个端口是单个文件部署用到的端口
  static int shelfPortRangeStart = 13000;
  static int shelfPortRangeEnd = 13010;
  // 下面两个是聊天服务器的端口
  static int chatPortRangeStart = 12000;
  static int chatPortRangeEnd = 12010;
  // 包名
  static String packageName = 'com.nightmare.fastshare';
  // flutter package名，因为这个会影响assets的路径
  static String flutterPackage = '';

  static String? package;

  static String packageConst = 'packages/speed_share/';

  static String versionName = const String.fromEnvironment('VERSION');
  static String versionCode = const String.fromEnvironment('VERSION_CODE');

  // CI 编译时没有传 --dart-define=VERSION，这时从安装包里读 pubspec.yaml 写的版本号
  static Future<void> initVersion() async {
    if (versionName.isNotEmpty) {
      return;
    }
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      versionName = info.version;
      versionCode = info.buildNumber;
    } catch (_) {}
  }
}
