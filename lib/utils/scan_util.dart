import 'dart:io';

import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/modules/qrscan_page.dart';

/// 解析二维码
class ScanUtil {
  /// 扫码用的 mobile_scanner 没有 Windows 和 Linux 的实现，在这两个平台上打开扫码页只会是一片空白
  static bool get isSupported => !GetPlatform.isWindows && !GetPlatform.isLinux;

  static Future<void> parseScan() async {
    if (Platform.isAndroid) {
      await PermissionUtil.requestCamera();
    }
    final String? cameraScanResult = await Get.to(
      () => const QRScanPage(),
      preventDuplicates: false,
      fullscreenDialog: true,
    );
    if (cameraScanResult == null) {
      return;
    }
    Log.v('cameraScanResult -> $cameraScanResult');
    ChatController controller = Get.find();
    controller.sendJoinMessageByUrl(cameraScanResult);
  }
}
