/// 速享的文件管理模块。
///
/// - [FileManagerView]、[FileManagerPage]：本地文件浏览
/// - [FileManager]：应用内选择文件和文件夹
/// - [Server]：浏览器远程管理文件用的 HTTP 接口
library;

export 'server/file_server.dart';
export 'src/config.dart';
export 'src/file_manager.dart';
export 'src/storage.dart' show FileEntry, FileManagerError, FileManagerException;
export 'view/file_manager_page.dart';
export 'view/file_manager_view.dart';
