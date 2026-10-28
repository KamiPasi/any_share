import 'package:get/get.dart';

import '../view/file_manager_view.dart';
import '../view/file_picker_page.dart';

/// 应用内的文件和文件夹选择。
///
/// 选择页通过 GetX 打开，宿主需要使用 `GetMaterialApp`。
class FileManager {
  FileManager._();

  /// 选择一个或多个文件，返回它们的路径；取消时返回空列表。
  static Future<List<String>> selectFile() async {
    final result = await Get.to<List<String>>(
      () => const FilePickerPage(mode: PickMode.files),
    );
    return result ?? <String>[];
  }

  /// 选择一个文件夹，返回它的路径；取消时返回 null。
  static Future<String?> selectDirectory() async {
    final result = await Get.to<List<String>>(
      () => const FilePickerPage(mode: PickMode.directory),
    );
    if (result == null || result.isEmpty) return null;
    return result.first;
  }
}
