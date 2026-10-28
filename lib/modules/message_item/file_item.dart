import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:get/get.dart' hide Response;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/modules/widget/icon.dart';
import 'package:speed_share/common/common.dart';
import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/services/services.dart';
import 'package:speed_share/models/models.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/widgets/ui_kit.dart';

class FileItem extends StatefulWidget {
  /// 消息model
  final FileMessage? info;

  /// 是否是本机发送的消息
  final bool? sendByUser;

  const FileItem({
    Key? key,
    this.info,
    this.sendByUser,
  }) : super(key: key);
  @override
  State createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
  ChatController chatController = Get.find();
  SettingController settingController = Get.find();
  DownloadController downloadController = Get.find();
  FileMessage? info;

  @override
  void initState() {
    super.initState();
    info = widget.info;
    // 开启自动下载，且是来自其他设备的消息
    if (!GetPlatform.isWeb && canAutoDownload()) {
      downloadController.downloadFile(url, settingController.savePath);
    }
  }

  bool canAutoDownload() {
    if (widget.sendByUser!) {
      return false;
    }
    if (downloadController.progress.containsKey(url) && downloadController.progress[url]!.progress != 0.0) {
      return false;
    }
    if (!settingController.enableAutoDownloadSetting.value) return false;
    String type = url.fileTypeLabel;
    String savePath = '${settingController.savePath}/$type/${p.basename(url)}';
    File file = File(savePath);
    if (!file.existsSync()) {
      return true;
    }
    int len = file.lengthSync();
    if (file.existsSync()) {
      if (widget.info!.fileSize != FileUtil.formatBytes(len)) return true;
      if (widget.info!.fileSize == FileUtil.formatBytes(len)) return false;
    }
    return true;
  }

  String get url {
    String url;
    if (widget.sendByUser!) {
      url = 'http://127.0.0.1:${FileService.port}${widget.info!.filePath}';
    } else {
      url = widget.info!.url! + widget.info!.filePath!;
    }
    return url;
  }

  Future<void> download() async {
    if (GetPlatform.isWeb) {
      Log.e('web download $url');
      await canLaunchUrlString(url) ? await launchUrlString('$url?download=true') : throw 'Could not launch $url';
      return;
    }
    if (GetPlatform.isDesktop) {
      final dir = settingController.savePath;
      Log.e(' -> $url');
      downloadController.downloadFile(url, dir);
    } else {
      Directory dataDir = Directory('/sdcard/SpeedShare');
      if (!dataDir.existsSync()) {
        dataDir.createSync();
      }
      downloadController.downloadFile(
        url,
        '/sdcard/SpeedShare',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool mine = widget.sendByUser!;
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: UiBubble(
              sendByUser: mine,
              padding: const EdgeInsets.all(12),
              child: body(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget body(BuildContext context) {
    final bool mine = widget.sendByUser!;
    // 展示下载进度
    final bool showProgress = !mine && !GetPlatform.isWeb;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            UiFileBadge(
              highlighted: mine,
              child: getIconByExt(url, context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.info!.fileName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppUi.text, height: 1.35),
                  ),
                  const SizedBox(height: 2),
                  if (showProgress)
                    GetBuilder<DownloadController>(
                      builder: (_) => downloadStatus(),
                    )
                  else
                    Text(
                      widget.info!.fileSize ?? '',
                      style: const TextStyle(fontSize: 12, color: AppUi.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (showProgress)
          GetBuilder<DownloadController>(
            builder: (_) => downloadProgress(),
          ),
        // 别的设备发来的文件才有下载按钮
        if (!mine) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              UiButton(
                label: '下载',
                icon: Icons.download_rounded,
                variant: UiButtonVariant.soft,
                dense: true,
                height: 34,
                onPressed: download,
              ),
              const SizedBox(width: 8),
              UiButton(
                label: '复制链接',
                icon: Icons.link_rounded,
                dense: true,
                height: 34,
                onPressed: () => uiCopy(url),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget downloadStatus() {
    final DownloadInfo info = downloadController.getInfo(url)!;
    final double progress = info.progress;
    final String size = widget.info!.fileSize ?? '';
    if (progress >= 1.0) {
      return Row(
        children: [
          const Icon(Icons.check_rounded, size: 14, color: AppUi.onlineText),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '已下载 · $size',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppUi.onlineText),
            ),
          ),
        ],
      );
    }
    if (progress > 0) {
      return Text(
        '${FileUtil.formatBytes(info.count)} / $size · ${info.speed}/s',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppUi.textSecondary),
      );
    }
    return Text(
      size,
      style: const TextStyle(fontSize: 12, color: AppUi.textSecondary),
    );
  }

  Widget downloadProgress() {
    final double progress = downloadController.getProgress(url);
    if (progress <= 0 || progress >= 1.0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          backgroundColor: AppUi.segment,
          color: AppUi.accent,
        ),
      ),
    );
  }
}
