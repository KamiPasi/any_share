import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart' hide Response;
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/common/common.dart';
import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/services/chat_service.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/models/models.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/widgets/ui_kit.dart';

class DirMessageItem extends StatefulWidget {
  const DirMessageItem({
    Key? key,
    this.info,
    this.sendByUser,
  }) : super(key: key);
  final bool? sendByUser;
  final DirMessage? info;

  @override
  State createState() => _DirMessageItemState();
}

class _DirMessageItemState extends State<DirMessageItem> {
  ChatController chatController = Get.find();
  DirMessage? info;
  final Dio dio = Dio();
  CancelToken cancelToken = CancelToken();
  int count = 0;
  double fileDownratio = 0.0;
  int downloadSize = 0;
  // 网速
  String? speed = '0';
  Timer? timer;
  Future<void> downloadFile(String? urlPath, String savePath) async {
    if (fileDownratio != 0.0) {
      showToast(l10n.fileIsDownloading);
      return;
    }
    String baseDirPath = '$savePath/${widget.info!.dirName}';
    // 这儿可能已经有一个文件名被占用了
    try {
      await Directory(baseDirPath).create();
    } catch (e) {
      showToast('${l10n.exceptionOrcur}：$e');
      return;
    }
    computeNetSpeed();
    for (String? path in widget.info!.paths!) {
      Log.d(path);
      // .*?是非贪婪匹配，
      String relativePath = path!.replaceAll(RegExp('.*?${widget.info!.dirName}/'), '/');
      // Log.e(relativePath);
      if (path.endsWith('/')) {
      } else {
        String tmpSavePath = '$savePath/${widget.info!.dirName}/$relativePath';
        // print(savePath);
        // Log.e(urlPath + '$path' + '?download=true');
        await dio.download(
          '$urlPath$path?download=true',
          tmpSavePath,
          cancelToken: cancelToken,
          onReceiveProgress: (count, total) {
            this.count = downloadSize + count;
            fileDownratio = this.count / widget.info!.fullSize!;
            setState(() {});
            if (count == total) {
              downloadSize += total;
            }
          },
        );
      }
    }
    timer?.cancel();
  }

  Future<void> computeNetSpeed() async {
    int tmpCount = 0;
    timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      int diff = count - tmpCount;
      tmpCount = count;
      // Log.e('diff -> $diff');
      // 乘以2是因为半秒测的一次
      speed = FileUtil.formatBytes(diff * 2);
      // *2 的原因是半秒测的一次
      // Log.e('网速 -> $speed');
    });
  }

  @override
  void initState() {
    super.initState();
    info = widget.info;
  }

  @override
  void dispose() {
    cancelToken.cancel();
    timer?.cancel();
    super.dispose();
  }

  Future<void> startDownload(String? urlPrifix) async {
    if (GetPlatform.isDesktop) {
      const confirmButtonText = 'Choose';
      final dir = await getDirectoryPath(
        confirmButtonText: confirmButtonText,
      );
      if (dir == null) {
        return;
      }
      downloadFile(urlPrifix, dir);
    } else {
      Directory dataDir = Directory('/sdcard/SpeedShare');
      if (!dataDir.existsSync()) {
        dataDir.createSync();
      }
      downloadFile(urlPrifix, '/sdcard/SpeedShare/文件夹');
    }
  }

  String statusText() {
    final String total = FileUtil.formatBytes(widget.info!.fullSize ?? 0);
    if (widget.sendByUser! || GetPlatform.isWeb) {
      return '文件夹 · $total';
    }
    if (fileDownratio >= 1.0) {
      return '已下载 · $total';
    }
    if (fileDownratio > 0) {
      return '${FileUtil.formatBytes(count)} / $total · $speed/s';
    }
    return '文件夹 · $total';
  }

  @override
  Widget build(BuildContext context) {
    String? urlPrifix;
    if (widget.sendByUser!) {
      urlPrifix = 'http://127.0.0.1:${ChatService.port}';
    } else {
      urlPrifix = info!.urlPrifix;
    }
    Log.v('urlPrifix -> $urlPrifix');
    final bool mine = widget.sendByUser!;
    final bool downloading = !mine && !GetPlatform.isWeb && fileDownratio > 0 && fileDownratio < 1.0;
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: UiBubble(
              sendByUser: mine,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      UiFileBadge(
                        highlighted: mine,
                        child: SvgPicture.asset(
                          SvgAssets.dir,
                          width: 36,
                          height: 36,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.info!.dirName!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppUi.text, height: 1.35),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              statusText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: !mine && fileDownratio >= 1.0 ? AppUi.onlineText : AppUi.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (downloading)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: fileDownratio,
                          minHeight: 4,
                          backgroundColor: AppUi.segment,
                          color: AppUi.accent,
                        ),
                      ),
                    ),
                  // 别的设备发来的文件夹才有下载按钮
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
                          onPressed: () => startDownload(urlPrifix),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
