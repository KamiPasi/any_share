import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart' as gr;

import 'package:speed_share/common/common.dart';
import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/models/models.dart';
import 'package:speed_share/modules/widget/icon.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/widgets/ui_kit.dart';
import 'package:speed_share/utils/utils.dart';

class BroswerFileItem extends StatefulWidget {
  /// 消息model
  final BrowserFileMessage? info;

  /// 是否是本机发送的消息
  final bool? sendByUser;

  const BroswerFileItem({
    Key? key,
    this.info,
    this.sendByUser,
  }) : super(key: key);
  @override
  State createState() => _BroswerFileItemState();
}

class _BroswerFileItemState extends State<BroswerFileItem> {
  ChatController chatController = Get.find();
  SettingController settingController = Get.find();
  DownloadController downloadController = Get.find();
  BrowserFileMessage? info;

  DateTime? startTime;
  bool isStarted = false;
  // 执行下载文件

  @override
  void initState() {
    super.initState();
    info = widget.info;
  }

  Offset? offset;

  String? get url {
    String? url;
    if (widget.sendByUser!) {
      url = widget.info!.blob;
    } else {
      url = widget.info!.blob;
    }
    return url;
  }

  // 让浏览器把文件传上来，传完才能下载
  void requestUpload() {
    if (GetPlatform.isWeb) {
      return;
    }
    gr.showToast(l10n.notifyBroswerTip);
    chatController.notifyBrowserUploadFile(widget.info!.hash);
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
              child: buildPreviewWidget(),
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
        if (!mine)
          GetBuilder<DownloadController>(
            builder: (_) => actions(),
          ),
      ],
    );
  }

  // 新网页端选完文件就直接上传，旧网页端要这边点「下载」才开始传
  Widget actions() {
    final DownloadInfo info = downloadController.getInfo(url)!;
    final Widget button;
    if (info.progress >= 1.0 && info.path != null) {
      button = UiButton(
        label: '打开',
        icon: Icons.open_in_new_rounded,
        variant: UiButtonVariant.soft,
        dense: true,
        height: 34,
        onPressed: () => FileUtil.openFile(info.path!),
      );
    } else if (info.progress > 0) {
      // 正在接收，进度条在上面
      return const SizedBox.shrink();
    } else {
      button = UiButton(
        label: '下载',
        icon: Icons.download_rounded,
        variant: UiButtonVariant.soft,
        dense: true,
        height: 34,
        onPressed: requestUpload,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [button]),
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
        '${gr.FileUtil.formatBytes(info.count)} / $size · ${info.speed}/s',
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

  Widget buildPreviewWidget() {
    if (widget.info!.fileName!.isImageFile && widget.sendByUser!) {
      // 文件名是图片的时候，用blob协议展示
      return GestureDetector(
        onTap: () {
          FileUtil.openFile(widget.info!.blob!);
        },
        child: Image(
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          image: ResizeImage(
            NetworkImage(widget.info!.blob!),
            width: 100,
          ),
        ),
      );
    }
    // 传入文件名，已展示对应的图标
    return getIconByExt(widget.info!.fileName!, context);
  }
}
