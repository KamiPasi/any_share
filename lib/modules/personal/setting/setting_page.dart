import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:global_repository/global_repository.dart';
import 'package:file_manager/file_manager.dart' as file_manager;

import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/services/services.dart';
import 'package:speed_share/routes/app_pages.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/utils/lan_address.dart';
import 'package:speed_share/widgets/ui_kit.dart';

import 'dialog/select_language.dart';

Future<int> getCacheSize(Directory cacheDir) async {
  int totalSize = 0;

  if (await cacheDir.exists()) {
    try {
      await for (FileSystemEntity entity in cacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      Log.e('Error calculating cache size: $e');
    }
  }

  return totalSize;
}

// 设置页面
class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  SettingController controller = Get.find();
  ChatController chatController = Get.find();
  String cacheSize = '';
  Directory? cache;
  // 网页文件服务打开时，列出可以访问的地址
  List<LanAddress> addresses = [];

  @override
  void initState() {
    super.initState();
    getp();
    lanAddresses().then((value) {
      if (mounted) {
        setState(() => addresses = value);
      }
    });
  }

  Future<void> getp() async {
    cache = await getApplicationCacheDirectory();
    Log.i('cache:${cache!.path}');
    final int value = await getCacheSize(cache!);
    Log.d('Cache size: ${value / (1024 * 1024)} MB');
    if (!mounted) {
      return;
    }
    setState(() {
      cacheSize = '${(value / (1024 * 1024)).toStringAsFixed(2)} MB';
    });
  }

  Future<void> changeSavePath() async {
    if (GetPlatform.isDesktop) {
      final path = await getDirectoryPath(
        confirmButtonText: l10n.select,
      );
      Log.e('path:$path');
      if (path != null) {
        controller.switchDownLoadPath(path);
      }
    } else {
      String? path = await file_manager.FileManager.selectDirectory();
      if (path != null) {
        controller.switchDownLoadPath(path);
      }
    }
  }

  Future<void> openSaveFolder() async {
    final String? path = controller.savePath;
    if (path == null) {
      return;
    }
    try {
      // 还没收到过文件时目录可能还不存在
      await Directory(path).create(recursive: true);
      await launchUrl(Uri.file(path));
    } catch (e) {
      showToast('打不开文件夹：$e');
    }
  }

  Future<void> clearCache() async {
    if (cache == null) {
      return;
    }
    try {
      await cache!.delete(recursive: true);
    } catch (e) {
      Log.e('clear cache error: $e');
    }
    await getp();
    showToast('缓存清理完成');
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveBreakpoints.of(context).isMobile;
    // 作为单独的页面打开时（不在首页的标签里）需要返回按钮
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final double side = isMobile ? 16 : 24;
    return Scaffold(
      backgroundColor: AppUi.background,
      body: SafeArea(
        left: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(canPop ? 8 : side, 12, side, 12),
              decoration: const BoxDecoration(
                color: AppUi.surface,
                border: Border(bottom: BorderSide(color: AppUi.border)),
              ),
              child: Row(
                children: [
                  if (canPop) ...[
                    UiIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.setting,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppUi.text, height: 1.4),
                        ),
                        const Text(
                          '改动立即生效',
                          style: TextStyle(fontSize: 13, color: AppUi.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GetBuilder<SettingController>(
                builder: (controller) {
                  return ListView(
                    padding: EdgeInsets.symmetric(horizontal: side, vertical: side),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingGroup(title: l10n.common, children: generalItems(controller)),
                              const SizedBox(height: 24),
                              _SettingGroup(title: l10n.fileType, children: fileItems(controller)),
                              const SizedBox(height: 24),
                              _SettingGroup(title: l10n.aboutSpeedShare, children: aboutItems()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> generalItems(SettingController controller) {
    return [
      _SettingRow(
        title: l10n.downlaodPath,
        subtitle: controller.savePath ?? '',
        subtitleStyle: AppUi.mono(fontSize: 13, color: AppUi.textSecondary),
        onTap: changeSavePath,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (GetPlatform.isDesktop) ...[
              UiButton(
                label: '打开',
                dense: true,
                height: 34,
                onPressed: openSaveFolder,
              ),
              const SizedBox(width: 8),
            ],
            UiButton(
              label: '更改',
              dense: true,
              height: 34,
              onPressed: changeSavePath,
            ),
          ],
        ),
      ),
      _SettingRow(
        title: l10n.lang,
        onTap: () {
          Get.dialog(const SelectLang());
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.currentLocaleKey ?? '',
              style: const TextStyle(fontSize: 14, color: AppUi.textSecondary),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppUi.textSecondary),
          ],
        ),
      ),
      _SwitchRow(
        title: l10n.autoDownload,
        subtitle: '收到的文件直接存到下载路径，不用一个个点下载',
        value: controller.enableAutoDownloadSetting.value == true,
        onChanged: controller.enableAutoChange,
      ),
      _SwitchRow(
        title: l10n.clipboardshare,
        subtitle: '在设备之间同步复制的文字',
        value: controller.clipboardShareSetting.value == true,
        onChanged: controller.clipChange,
      ),
      if (!GetPlatform.isDesktop)
        _SwitchRow(
          title: l10n.messageNote,
          value: controller.vibrate,
          onChanged: controller.vibrateChange,
        ),
    ];
  }

  List<Widget> fileItems(SettingController controller) {
    final List<String> cacheTips = [
      if (cacheSize.isNotEmpty) '当前占用 $cacheSize',
      if (GetPlatform.isAndroid) l10n.androidSAFTips,
    ];
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchRow(
            title: l10n.enableWebServer,
            subtitle: '让局域网里的设备用浏览器浏览这台设备上的文件，默认关闭',
            value: controller.enableWebServer,
            onChanged: controller.changeWebServer,
          ),
          if (controller.enableWebServer) webServerWarning(),
        ],
      ),
      _SettingRow(
        title: l10n.clearCache,
        subtitle: cacheTips.join('\n'),
        trailing: UiButton(
          label: '清理',
          dense: true,
          height: 34,
          onPressed: cache == null ? null : clearCache,
        ),
      ),
    ];
  }

  Widget webServerWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUi.warningBackground,
        border: Border.all(color: AppUi.warningBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, size: 18, color: AppUi.warningIcon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '已开启。同一局域网里的任何人打开下面的地址，都能浏览、下载和删除这台设备上的文件，用完记得关掉。',
                  style: TextStyle(fontSize: 13, color: AppUi.warningText, height: 1.5),
                ),
                for (final LanAddress address in addresses) ...[
                  const SizedBox(height: 8),
                  UiCopyField(
                    text: '${address.url(ChatService.port)}/sdcard',
                    filledButton: false,
                    background: AppUi.surface,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> aboutItems() {
    const Widget chevron = Icon(Icons.chevron_right_rounded, size: 20, color: AppUi.textSecondary);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppUi.accent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.share_rounded, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '速享',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppUi.text),
                  ),
                  Text(
                    '${l10n.developer} 梦魇兽 · ${l10n.ui} 柚凛 / 梦魇兽',
                    style: const TextStyle(fontSize: 13, color: AppUi.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _SettingRow(
        title: l10n.changeLog,
        trailing: chevron,
        onTap: () {
          Get.toNamed(AppPages.changeLog);
        },
      ),
      _SettingRow(
        title: l10n.privacyAgreement,
        trailing: chevron,
        onTap: () {
          Get.toNamed(AppPages.about);
        },
      ),
      _SettingRow(
        title: '开源许可',
        trailing: chevron,
        onTap: () async {
          String license = await rootBundle.loadString('LICENSE');
          Get.toNamed('/about', arguments: license);
        },
      ),
    ];
  }
}

/// 一组设置项：小标题加一张卡片，卡片里的项之间有分隔线
class _SettingGroup extends StatelessWidget {
  const _SettingGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, thickness: 1, indent: 18, endIndent: 18, color: AppUi.divider));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppUi.textSecondary),
          ),
        ),
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String text = subtitle ?? '';
    final Widget? end = trailing;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppUi.text),
                    ),
                    if (text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          text,
                          style: subtitleStyle ?? const TextStyle(fontSize: 13, color: AppUi.textSecondary, height: 1.45),
                        ),
                      ),
                  ],
                ),
              ),
              if (end != null) ...[
                const SizedBox(width: 12),
                end,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
