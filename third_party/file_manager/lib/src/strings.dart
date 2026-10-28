import 'package:flutter/widgets.dart';

import 'storage.dart';

/// 界面文字：中文环境显示中文，其他语言显示英文。
class FmStrings {
  const FmStrings._(this._zh);

  final bool _zh;

  static FmStrings of(BuildContext context) =>
      FmStrings._(Localizations.maybeLocaleOf(context)?.languageCode == 'zh');

  String _t(String zh, String en) => _zh ? zh : en;

  String get fileManager => _t('文件管理', 'Files');
  String get up => _t('上一级', 'Up');
  String get refresh => _t('刷新', 'Refresh');
  String get newFolder => _t('新建文件夹', 'New folder');
  String get showHidden => _t('显示隐藏文件', 'Show hidden files');
  String get hideHidden => _t('不显示隐藏文件', 'Hide hidden files');
  String get open => _t('打开', 'Open');
  String get rename => _t('重命名', 'Rename');
  String get delete => _t('删除', 'Delete');
  String get cancel => _t('取消', 'Cancel');
  String get ok => _t('确定', 'OK');
  String get retry => _t('重试', 'Retry');
  String get emptyFolder => _t('文件夹是空的', 'This folder is empty');
  String get cannotRead => _t('无法打开这个文件夹', "Can't open this folder");
  String get permissionHint => _t(
        '请在系统设置里允许本应用访问所有文件。',
        'Allow this app to access all files in system settings.',
      );
  String get folderName => _t('文件夹名称', 'Folder name');
  String get newName => _t('新名称', 'New name');
  String get selectFiles => _t('选择文件', 'Select files');
  String get selectFolder => _t('选择文件夹', 'Select folder');
  String get useThisFolder => _t('选择当前文件夹', 'Use this folder');

  String confirmCount(int count) => count == 0 ? ok : _t('确定（$count）', 'OK ($count)');

  String deleteConfirm(String name, bool isDirectory) => _zh
      ? '确定删除“$name”吗？${isDirectory ? '文件夹里的内容会一起删除。' : ''}'
      : 'Delete "$name"?${isDirectory ? ' Everything inside it will be deleted too.' : ''}';

  String openFailed(String message) => _t('无法打开：$message', "Can't open: $message");

  String failed(String message) => _t('操作失败：$message', 'Failed: $message');

  String error(FileManagerException e) => switch (e.error) {
        FileManagerError.invalidName => _t('不能用这个名称：${e.name}', 'Invalid name: ${e.name}'),
        FileManagerError.alreadyExists =>
          _t('已经有叫“${e.name}”的文件或文件夹了', 'Already exists: ${e.name}'),
        FileManagerError.notFound => _t('找不到“${e.name}”', 'Not found: ${e.name}'),
      };

  /// [Storage.places] 返回的位置名称
  String place(String key, String path) => switch (key) {
        'storage' => _t('内部存储', 'Internal storage'),
        'home' => _t('主目录', 'Home'),
        'desktop' => _t('桌面', 'Desktop'),
        'download' => _t('下载', 'Downloads'),
        'documents' => _t('文档', 'Documents'),
        'camera' => _t('相机', 'Camera'),
        'pictures' => _t('图片', 'Pictures'),
        'root' => _t('根目录', 'Root'),
        _ => path,
      };
}
