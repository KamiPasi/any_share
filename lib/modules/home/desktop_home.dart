import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/routes/app_pages.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/modules/desktop_drawer.dart';
import 'package:speed_share/modules/personal/setting/setting_page.dart';
import 'package:speed_share/modules/share_chat_window.dart';
import 'package:speed_share/themes/app_ui.dart';

class DesktopHome extends StatefulWidget {
  const DesktopHome({Key? key}) : super(key: key);

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  String page = AppPages.home;
  ChatController controller = Get.find();
  bool dropping = false;

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    Log.d('files -> ${event.session.items}');

    final fileUris = <Uri>[];
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;
      final completer = Completer<Uri?>();
      final progress = reader.getValue(
        Formats.fileUri,
        (Uri? uri) {
          if (!completer.isCompleted) completer.complete(uri);
        },
        onError: (e) {
          if (!completer.isCompleted) completer.complete(null);
        },
      );
      if (progress == null) completer.complete(null);
      final uri = await completer.future;
      if (uri != null && uri.scheme == 'file') {
        fileUris.add(uri);
      }
    }

    setState(() {});

    if (fileUris.isEmpty) return;

    if (GetPlatform.isAndroid) {
      for (final uri in fileUris) {
        // TODO: Check!
        final filePath = path.fromUri(uri).replaceAll('/raw/', '');
        controller.sendFileMessageByPath(filePath);
      }
      return;
    }

    if (fileUris.length == 1 && await FileSystemEntity.isDirectory(fileUris.first.toFilePath())) {
      controller.sendDirMessageByPath(fileUris.first.toFilePath());
    } else {
      for (final uri in fileUris) {
        controller.sendFileMessageByPath(uri.toFilePath());
      }
    }
  }

  Widget getPage() {
    return {
      AppPages.home: const ShareChatV2(),
      AppPages.setting: const SettingPage(),
    }[page]!;
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        return event.session.allowedOperations.firstOrNull ?? DropOperation.none;
      },
      onDropEnter: (event) {
        setState(() {
          dropping = true;
        });
      },
      onDropLeave: (event) {
        setState(() {
          dropping = false;
        });
      },
      onPerformDrop: _onPerformDrop,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppUi.background,
            body: SafeArea(
              left: false,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DesktopDrawer(
                          value: page,
                          onChange: (value) {
                            page = value;
                            setState(() {});
                          },
                        ),
                        GetBuilder<DeviceController>(
                          builder: (controller) {
                            return Expanded(
                              child: getPage(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (dropping)
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 4.0,
                sigmaY: 4.0,
              ),
              child: Material(
                color: AppUi.background.withValues(alpha: 0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    decoration: BoxDecoration(
                      color: AppUi.surface,
                      border: Border.all(color: AppUi.accent, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.file_upload_outlined, size: 40, color: AppUi.accent),
                        const SizedBox(height: 12),
                        Text(
                          l10n.dropFileTip,
                          style: const TextStyle(
                            color: AppUi.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
