import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

/// 文件夹里的一项。
class FileEntry {
  const FileEntry({
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
    required this.mode,
  });

  /// 本机上的完整路径
  final String path;

  final bool isDirectory;

  /// 文件大小（字节），文件夹为 0
  final int size;

  final DateTime modified;

  /// `rwxr-xr-x` 形式的权限
  final String mode;

  String get name => p.basename(path);

  bool get isHidden => name.startsWith('.');
}

/// [FileManagerException] 的原因
enum FileManagerError {
  /// 名称为空、是 `.` 或 `..`，或者含有不能用在文件名里的字符
  invalidName,

  /// 已经有同名的文件或文件夹
  alreadyExists,

  /// 文件或文件夹不存在
  notFound,
}

/// 新建、重命名、删除时参数不对会抛出。
class FileManagerException implements Exception {
  const FileManagerException(this.error, this.name);

  final FileManagerError error;

  /// 出问题的名称
  final String name;

  @override
  String toString() => switch (error) {
        FileManagerError.invalidName => 'Invalid name: $name',
        FileManagerError.alreadyExists => 'Already exists: $name',
        FileManagerError.notFound => 'Not found: $name',
      };
}

/// 文件系统操作，界面和 HTTP 接口共用。
class Storage {
  Storage._();

  /// 网页端约定的根路径，对应本机的 [root]。
  static const String virtualRoot = '/sdcard';

  static String? _root;

  /// 浏览的起始目录：安卓是内部存储，其他平台是用户主目录。
  static String get root => _root ??= _resolveRoot();

  /// 提前确定 [root]。
  static void init() => _root ??= _resolveRoot();

  static String _resolveRoot() {
    if (Platform.isAndroid) {
      for (final dir in const ['/sdcard', '/storage/emulated/0']) {
        if (Directory(dir).existsSync()) return dir;
      }
    }
    final home = Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home != null && home.isNotEmpty && Directory(home).existsSync()) {
      return home;
    }
    return Directory.current.path;
  }

  /// 常用位置，按 (名称键, 路径) 返回，只包含本机上存在的。
  ///
  /// 名称键有 storage、home、desktop、download、documents、camera、pictures、root、drive。
  static List<(String, String)> places() {
    final places = <(String, String)>[];
    void add(String key, String path) {
      if (Directory(path).existsSync()) places.add((key, path));
    }

    if (Platform.isAndroid) {
      add('storage', root);
      add('download', p.join(root, 'Download'));
      add('documents', p.join(root, 'Documents'));
      add('camera', p.join(root, 'DCIM'));
      add('pictures', p.join(root, 'Pictures'));
      return places;
    }
    add('home', root);
    add('desktop', p.join(root, 'Desktop'));
    add('download', p.join(root, 'Downloads'));
    add('documents', p.join(root, 'Documents'));
    if (Platform.isWindows) {
      for (var letter = 'C'.codeUnitAt(0); letter <= 'Z'.codeUnitAt(0); letter++) {
        add('drive', '${String.fromCharCode(letter)}:\\');
      }
    } else {
      add('root', '/');
    }
    return places;
  }

  /// 列出 [dir] 的内容，文件夹在前，再按名称排序。读取失败时抛出 [FileSystemException]。
  static Future<List<FileEntry>> list(String dir) async {
    final paths = [
      await for (final entity in Directory(dir).list(followLinks: false)) entity.path,
    ];
    final entries = (await Future.wait(paths.map(stat))).whereType<FileEntry>().toList();
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// 读取 [path] 的信息，链接取它指向的目标；不存在（包括失效的链接）时返回 null。
  static Future<FileEntry?> stat(String path) async {
    final info = await FileStat.stat(path);
    if (info.type == FileSystemEntityType.notFound) return null;
    final isDirectory = info.type == FileSystemEntityType.directory;
    return FileEntry(
      path: path,
      isDirectory: isDirectory,
      size: isDirectory ? 0 : info.size,
      modified: info.modified,
      mode: info.modeString(),
    );
  }

  /// 把网页端的路径（如 `/sdcard/Download`）转换成本机路径，超出 [root] 时返回 null。
  static String? toLocal(String virtualPath) {
    final normalized = p.posix.normalize(
      virtualPath.startsWith('/') ? virtualPath : '/$virtualPath',
    );
    if (normalized != virtualRoot && !p.posix.isWithin(virtualRoot, normalized)) {
      return null;
    }
    final relative = p.posix.relative(normalized, from: virtualRoot);
    if (relative == '.') return root;
    final local = p.normalize(p.joinAll([root, ...p.posix.split(relative)]));
    // Windows 上片段里的反斜杠也能跳到上级目录，所以转换完再检查一次
    if (!p.isWithin(root, local)) return null;
    return local;
  }

  /// [toLocal] 的反向转换。
  static String toVirtual(String localPath) {
    final relative = p.relative(localPath, from: root);
    if (relative == '.') return virtualRoot;
    return p.posix.joinAll([virtualRoot, ...p.split(relative)]);
  }

  /// 网页端用的目录列表，格式和 `ls -aog` 的输出一致，每项一行：
  ///
  /// ```text
  /// drwxrwx--x  5 3488 2024-01-15 10:22 .
  /// drwxrwx--x 12 3488 2024-01-15 10:22 ..
  /// -rw-rw----  1  512 2024-01-15 10:22 a.txt
  /// ```
  ///
  /// 网页端按空白拆列：第 2 列当作文件夹里的项数，第 3 列当作文件大小，第 4、5 列是修改时间；
  /// 名称则从第一行时间后面的位置截取，所以各列要补空格对齐，让名称都从同一列开始。
  static Future<List<String>> listing(String dir) async {
    final items = <(FileEntry, String)>[];
    final self = await stat(dir);
    if (self != null) items.add((self, '.'));
    if (p.isWithin(root, dir)) {
      final parent = await stat(p.dirname(dir));
      if (parent != null) items.add((parent, '..'));
    }
    for (final entry in await list(dir)) {
      items.add((entry, entry.name));
    }
    final rows = await Future.wait([
      for (final (entry, name) in items) _listingRow(entry, name),
    ]);
    final countWidth = rows.fold<int>(0, (width, row) => math.max(width, row[1].length));
    final sizeWidth = rows.fold<int>(0, (width, row) => math.max(width, row[2].length));
    return [
      for (final row in rows)
        [
          row[0].padRight(10),
          row[1].padLeft(countWidth),
          row[2].padLeft(sizeWidth),
          row[3],
          row[4],
          row[5],
        ].join(' '),
    ];
  }

  static Future<List<String>> _listingRow(FileEntry entry, String name) async {
    final count = entry.isDirectory ? await _childCount(entry.path) : 1;
    return [
      '${entry.isDirectory ? 'd' : '-'}${entry.mode}',
      '$count',
      '${entry.size}',
      _date(entry.modified),
      _time(entry.modified),
      name,
    ];
  }

  static Future<int> _childCount(String dir) async {
    try {
      return await Directory(dir).list(followLinks: false).length;
    } on FileSystemException {
      return 0;
    }
  }

  /// [name] 能否用作文件或文件夹名。
  static bool isValidName(String name) {
    if (name.trim().isEmpty || name == '.' || name == '..') return false;
    if (name.contains('/') || name.contains('\\')) return false;
    return !Platform.isWindows || !RegExp(r'[<>:"|?*]').hasMatch(name);
  }

  /// 在 [parent] 下新建文件夹 [name]，返回它的路径。
  static Future<String> createDirectory(String parent, String name) async {
    _checkName(name);
    final path = p.join(parent, name);
    await _checkFree(path);
    await Directory(path).create();
    return path;
  }

  /// 把 [path] 改名为同一文件夹下的 [name]，返回新路径。
  static Future<String> rename(String path, String name) async {
    _checkName(name);
    final type = await _typeOf(path);
    final target = p.join(p.dirname(path), name);
    if (target == path) return path;
    // 只改大小写时，不区分大小写的文件系统会认为目标已存在
    if (!p.equals(target, path)) await _checkFree(target);
    await _entity(path, type).rename(target);
    return target;
  }

  /// 删除 [path]，文件夹连同里面的内容一起删除。
  static Future<void> delete(String path) async {
    final type = await _typeOf(path);
    await _entity(path, type).delete(recursive: type == FileSystemEntityType.directory);
  }

  /// [dir] 下可用的文件路径，重名时在名称后加上 ` (1)`、` (2)`……
  static Future<String> availablePath(String dir, String name) async {
    _checkName(name);
    final base = p.basenameWithoutExtension(name);
    final extension = p.extension(name);
    var path = p.join(dir, name);
    for (var i = 1; await _exists(path); i++) {
      path = p.join(dir, '$base ($i)$extension');
    }
    return path;
  }

  static void _checkName(String name) {
    if (!isValidName(name)) {
      throw FileManagerException(FileManagerError.invalidName, name);
    }
  }

  static Future<void> _checkFree(String path) async {
    if (await _exists(path)) {
      throw FileManagerException(FileManagerError.alreadyExists, p.basename(path));
    }
  }

  static Future<bool> _exists(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    return type != FileSystemEntityType.notFound;
  }

  static Future<FileSystemEntityType> _typeOf(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileManagerException(FileManagerError.notFound, p.basename(path));
    }
    return type;
  }

  static FileSystemEntity _entity(String path, FileSystemEntityType type) {
    if (type == FileSystemEntityType.directory) return Directory(path);
    if (type == FileSystemEntityType.link) return Link(path);
    return File(path);
  }

  /// 文件大小的显示文字，如 `1.5 MB`。
  static String formatSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    if (unit == 0) return '$bytes B';
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
  }

  /// 修改时间的显示文字，如 `2024-01-15 10:22`。
  static String formatTime(DateTime time) => '${_date(time)} ${_time(time)}';

  static String _date(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-${_two(time.month)}-${_two(time.day)}';

  static String _time(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
