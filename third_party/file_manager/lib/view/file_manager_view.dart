import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

import '../src/storage.dart';
import '../src/strings.dart';

/// [FileManagerView] 的用途。
enum PickMode {
  /// 浏览：可以打开、重命名、删除
  none,

  /// 选择一个或多个文件
  files,

  /// 选择一个文件夹
  directory,
}

/// [FileManagerView] 的状态：当前文件夹、它的内容和选中的文件。
class FileManagerController extends ChangeNotifier {
  FileManagerController({String? initialPath, this.mode = PickMode.none})
      : _path = initialPath ?? Storage.root;

  final PickMode mode;

  String _path;
  List<FileEntry> _entries = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  Object? _error;
  bool _showHidden = false;
  int _generation = 0;
  bool _disposed = false;

  /// 当前文件夹
  String get path => _path;

  bool get loading => _loading;

  /// 读取当前文件夹失败的原因
  Object? get error => _error;

  bool get showHidden => _showHidden;

  bool get canGoUp => p.dirname(_path) != _path;

  /// 当前文件夹的内容，不显示隐藏文件时已经过滤掉
  List<FileEntry> get entries =>
      _showHidden ? _entries : [for (final entry in _entries) if (!entry.isHidden) entry];

  /// 选中的文件路径，可以跨文件夹选择
  List<String> get selected => List.unmodifiable(_selected);

  bool isSelected(FileEntry entry) => _selected.contains(entry.path);

  /// 打开文件夹 [dir]
  Future<void> open(String dir) async {
    final generation = ++_generation;
    if (dir != _path) _entries = const [];
    _path = dir;
    _loading = true;
    _error = null;
    _notify();
    try {
      final entries = await Storage.list(dir);
      if (generation != _generation) return;
      _entries = entries;
    } catch (e) {
      if (generation != _generation) return;
      _entries = const [];
      _error = e;
    }
    _loading = false;
    _notify();
  }

  Future<void> refresh() => open(_path);

  Future<void> up() => open(p.dirname(_path));

  void toggleHidden() {
    _showHidden = !_showHidden;
    _notify();
  }

  void toggle(FileEntry entry) {
    if (!_selected.remove(entry.path)) _selected.add(entry.path);
    _notify();
  }

  Future<void> createDirectory(String name) async {
    await Storage.createDirectory(_path, name);
    await refresh();
  }

  Future<void> rename(FileEntry entry, String name) async {
    final target = await Storage.rename(entry.path, name);
    if (_selected.remove(entry.path)) _selected.add(target);
    await refresh();
  }

  Future<void> delete(FileEntry entry) async {
    await Storage.delete(entry.path);
    _selected.remove(entry.path);
    await refresh();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 文件浏览组件：顶部是路径和操作，下面是当前文件夹的内容。
class FileManagerView extends StatefulWidget {
  const FileManagerView({super.key, this.controller});

  /// 不传时组件自己创建一个用于浏览的控制器
  final FileManagerController? controller;

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  FileManagerController? _ownController;

  FileManagerController get _controller =>
      widget.controller ?? (_ownController ??= FileManagerController());

  @override
  void initState() {
    super.initState();
    // 等第一帧之后再读取，避免在构建过程中通知其他监听者
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refresh();
    });
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        children: [
          _Toolbar(controller: controller),
          if (controller.loading && controller.entries.isNotEmpty)
            const LinearProgressIndicator(minHeight: 1)
          else
            const Divider(height: 1),
          Expanded(child: _Body(controller: controller)),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final FileManagerController controller;

  @override
  Widget build(BuildContext context) {
    final strings = FmStrings.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            tooltip: strings.up,
            icon: const Icon(Icons.arrow_upward),
            onPressed: controller.canGoUp ? controller.up : null,
          ),
          Expanded(child: _Breadcrumbs(controller: controller)),
          IconButton(
            tooltip: strings.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
          ),
          PopupMenuButton<VoidCallback>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              for (final (key, path) in Storage.places())
                PopupMenuItem(
                  value: () => controller.open(path),
                  child: _MenuRow(icon: _placeIcon(key), label: strings.place(key, path)),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: () => _createDirectory(context),
                child: _MenuRow(icon: Icons.create_new_folder_outlined, label: strings.newFolder),
              ),
              PopupMenuItem(
                value: controller.toggleHidden,
                child: _MenuRow(
                  icon: controller.showHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  label: controller.showHidden ? strings.hideHidden : strings.showHidden,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createDirectory(BuildContext context) async {
    final strings = FmStrings.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = await _askName(context, title: strings.newFolder, hint: strings.folderName);
    if (name == null || name.isEmpty) return;
    await _attempt(messenger, strings, () => controller.createDirectory(name));
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.controller});

  final FileManagerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crumbs = <(String, String)>[];
    var current = controller.path;
    while (true) {
      final parent = p.dirname(current);
      crumbs.insert(0, (parent == current ? current : p.basename(current), current));
      if (parent == current) break;
      current = parent;
    }
    final children = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final (label, path) = crumbs[i];
      final last = i == crumbs.length - 1;
      if (i > 0) children.add(Icon(Icons.chevron_right, size: 18, color: theme.hintColor));
      children.add(
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: last ? null : () => controller.open(path),
          child: Text(
            label,
            style: last
                ? TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)
                : null,
          ),
        ),
      );
    }
    // reverse 让最后一段（当前文件夹）默认可见
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(children: children),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final FileManagerController controller;

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    if (error != null) return _ErrorView(error: error, onRetry: controller.refresh);
    final entries = controller.entries;
    if (entries.isEmpty) {
      if (controller.loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Text(
          FmStrings.of(context).emptyFolder,
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) => _EntryTile(controller: controller, entry: entries[index]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = FmStrings.of(context);
    final theme = Theme.of(context);
    final error = this.error;
    final detail =
        error is FileSystemException ? (error.osError?.message ?? error.message) : '$error';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(strings.cannotRead, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(detail, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 4),
              Text(
                strings.permissionHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(strings.retry)),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.controller, required this.entry});

  final FileManagerController controller;
  final FileEntry entry;

  @override
  Widget build(BuildContext context) {
    final mode = controller.mode;
    final time = Storage.formatTime(entry.modified);
    return ListTile(
      enabled: entry.isDirectory || mode != PickMode.directory,
      selected: controller.isSelected(entry),
      leading: Icon(
        _entryIcon(entry),
        color: entry.isDirectory ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(entry.isDirectory ? time : '${Storage.formatSize(entry.size)} · $time'),
      trailing: switch (mode) {
        PickMode.files when !entry.isDirectory => Checkbox(
            value: controller.isSelected(entry),
            onChanged: (_) => controller.toggle(entry),
          ),
        PickMode.none => _EntryMenu(controller: controller, entry: entry),
        _ => null,
      },
      onTap: () => _onTap(context),
      onLongPress: mode == PickMode.none ? () => _showActions(context, controller, entry) : null,
    );
  }

  void _onTap(BuildContext context) {
    if (entry.isDirectory) {
      controller.open(entry.path);
      return;
    }
    switch (controller.mode) {
      case PickMode.files:
        controller.toggle(entry);
      case PickMode.directory:
        break;
      case PickMode.none:
        _openFile(context, entry);
    }
  }
}

class _EntryMenu extends StatelessWidget {
  const _EntryMenu({required this.controller, required this.entry});

  final FileManagerController controller;
  final FileEntry entry;

  @override
  Widget build(BuildContext context) {
    final strings = FmStrings.of(context);
    return PopupMenuButton<_Action>(
      onSelected: (action) => _run(context, controller, entry, action),
      itemBuilder: (_) => [
        for (final action in _actionsFor(entry))
          PopupMenuItem(
            value: action,
            child: _MenuRow(icon: action.icon, label: action.label(strings)),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

enum _Action {
  open(Icons.open_in_new),
  rename(Icons.drive_file_rename_outline),
  delete(Icons.delete_outline);

  const _Action(this.icon);

  final IconData icon;

  String label(FmStrings strings) => switch (this) {
        _Action.open => strings.open,
        _Action.rename => strings.rename,
        _Action.delete => strings.delete,
      };
}

List<_Action> _actionsFor(FileEntry entry) => [
      if (!entry.isDirectory) _Action.open,
      _Action.rename,
      _Action.delete,
    ];

Future<void> _showActions(
  BuildContext context,
  FileManagerController controller,
  FileEntry entry,
) async {
  final strings = FmStrings.of(context);
  final action = await showModalBottomSheet<_Action>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(entry.path, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          for (final item in _actionsFor(entry))
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label(strings)),
              onTap: () => Navigator.of(context).pop(item),
            ),
        ],
      ),
    ),
  );
  if (action != null && context.mounted) await _run(context, controller, entry, action);
}

Future<void> _run(
  BuildContext context,
  FileManagerController controller,
  FileEntry entry,
  _Action action,
) async {
  final strings = FmStrings.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  switch (action) {
    case _Action.open:
      await _openFile(context, entry);
    case _Action.rename:
      final name = await _askName(
        context,
        title: strings.rename,
        hint: strings.newName,
        initial: entry.name,
        selectBaseName: !entry.isDirectory,
      );
      if (name == null || name.isEmpty || name == entry.name) return;
      await _attempt(messenger, strings, () => controller.rename(entry, name));
    case _Action.delete:
      final confirmed = await _confirmDelete(context, entry);
      if (!confirmed) return;
      await _attempt(messenger, strings, () => controller.delete(entry));
  }
}

Future<void> _openFile(BuildContext context, FileEntry entry) async {
  final strings = FmStrings.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await OpenFile.open(entry.path);
  if (result.type != ResultType.done) {
    messenger?.showSnackBar(SnackBar(content: Text(strings.openFailed(result.message))));
  }
}

/// 执行文件操作，失败时用 SnackBar 提示
Future<void> _attempt(
  ScaffoldMessengerState? messenger,
  FmStrings strings,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on FileManagerException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(strings.error(e))));
  } on FileSystemException catch (e) {
    final message = e.osError?.message ?? e.message;
    messenger?.showSnackBar(SnackBar(content: Text(strings.failed(message))));
  }
}

Future<bool> _confirmDelete(BuildContext context, FileEntry entry) async {
  final strings = FmStrings.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(strings.delete),
        content: Text(strings.deleteConfirm(entry.name, entry.isDirectory)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.delete),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  bool selectBaseName = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      hint: hint,
      initial: initial,
      selectBaseName: selectBaseName,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.selectBaseName,
  });

  final String title;
  final String hint;
  final String initial;

  /// 只选中扩展名前面的部分，方便改名时保留扩展名
  final bool selectBaseName;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);

  @override
  void initState() {
    super.initState();
    final dot = widget.initial.lastIndexOf('.');
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.selectBaseName && dot > 0 ? dot : widget.initial.length,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_text.text.trim());

  @override
  Widget build(BuildContext context) {
    final strings = FmStrings.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(strings.cancel)),
        FilledButton(onPressed: _submit, child: Text(strings.ok)),
      ],
    );
  }
}

IconData _placeIcon(String key) => switch (key) {
      'storage' => Icons.phone_android,
      'home' => Icons.home_outlined,
      'desktop' => Icons.desktop_windows_outlined,
      'download' => Icons.download_outlined,
      'documents' => Icons.description_outlined,
      'camera' => Icons.photo_camera_outlined,
      'pictures' => Icons.image_outlined,
      _ => Icons.storage,
    };

const _imageTypes = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.svg'};
const _videoTypes = {'.mp4', '.mkv', '.mov', '.avi', '.wmv', '.flv', '.webm', '.3gp', '.rmvb'};
const _audioTypes = {'.mp3', '.flac', '.wav', '.aac', '.m4a', '.ogg', '.wma', '.ape'};
const _archiveTypes = {'.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz'};
const _documentTypes = {
  '.txt', '.md', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.csv', '.json', '.log',
};

IconData _entryIcon(FileEntry entry) {
  if (entry.isDirectory) return Icons.folder;
  final extension = p.extension(entry.name).toLowerCase();
  if (_imageTypes.contains(extension)) return Icons.image_outlined;
  if (_videoTypes.contains(extension)) return Icons.movie_outlined;
  if (_audioTypes.contains(extension)) return Icons.audiotrack_outlined;
  if (_archiveTypes.contains(extension)) return Icons.folder_zip_outlined;
  if (extension == '.apk') return Icons.android;
  if (extension == '.pdf') return Icons.picture_as_pdf_outlined;
  if (_documentTypes.contains(extension)) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}
