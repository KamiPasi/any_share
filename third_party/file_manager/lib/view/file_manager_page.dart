import 'package:flutter/material.dart';

import '../src/strings.dart';
import 'file_manager_view.dart';

/// 独立的文件管理页面。
class FileManagerPage extends StatelessWidget {
  const FileManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(FmStrings.of(context).fileManager)),
      body: const SafeArea(top: false, child: FileManagerView()),
    );
  }
}
