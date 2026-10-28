import 'package:flutter/material.dart';

import '../src/strings.dart';
import 'file_manager_view.dart';

/// 应用内的文件或文件夹选择页，确定后以 `List<String>` 返回选中的路径。
class FilePickerPage extends StatefulWidget {
  const FilePickerPage({super.key, required this.mode});

  /// [PickMode.files] 或 [PickMode.directory]
  final PickMode mode;

  @override
  State<FilePickerPage> createState() => _FilePickerPageState();
}

class _FilePickerPageState extends State<FilePickerPage> {
  late final FileManagerController _controller = FileManagerController(mode: widget.mode);

  bool get _pickDirectory => widget.mode == PickMode.directory;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(_pickDirectory ? [_controller.path] : _controller.selected);
  }

  @override
  Widget build(BuildContext context) {
    final strings = FmStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_pickDirectory ? strings.selectFolder : strings.selectFiles)),
      body: FileManagerView(controller: _controller),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(strings.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final count = _controller.selected.length;
                    return FilledButton(
                      onPressed: _pickDirectory || count > 0 ? _confirm : null,
                      child: Text(
                        _pickDirectory ? strings.useThisFolder : strings.confirmCount(count),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
