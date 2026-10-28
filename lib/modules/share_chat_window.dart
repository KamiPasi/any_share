import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:get/get.dart' hide Response;
import 'package:image_picker/image_picker.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:global_repository/global_repository.dart' hide GestureWithScale;
import 'package:file_manager/file_manager.dart' as file_manager;

import 'package:speed_share/common/common.dart';
import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/modules/widget/menu.dart';
import 'package:speed_share/services/services.dart';
import 'package:speed_share/utils/utils.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/widgets/ui_kit.dart';
import 'dialog/join_chat.dart';
import 'dialog/show_qr_page.dart';
import 'widget/connect_guide.dart';

// 聊天窗口
class ShareChatV2 extends StatefulWidget {
  const ShareChatV2({
    Key? key,
  }) : super(key: key);

  @override
  State createState() => _ShareChatV2State();
}

class _ShareChatV2State extends State<ShareChatV2> with SingleTickerProviderStateMixin {
  ChatController chatController = Get.find();
  // 附件菜单（图片、视频、文件、文件夹）的展开动画
  late AnimationController menuAnim;
  // 输入框控制器
  TextEditingController editingController = TextEditingController();
  FocusNode focusNode = FocusNode();

  bool inputMultiline = false;
  bool hasInput = false;

  @override
  void initState() {
    super.initState();
    editingController.addListener(() {
      // 输入框有内容时发送按钮才可用
      final bool value = editingController.text.isNotEmpty;
      if (value != hasInput) {
        setState(() {
          hasInput = value;
        });
      }
    });
    // 这里是shift+enter可以是实现换行的逻辑
    focusNode.onKeyEvent = (_, event) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        inputMultiline = true;
        setState(() {});
      } else {
        inputMultiline = false;
        setState(() {});
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        return KeyEventResult.skipRemainingHandlers;
      }
      return KeyEventResult.ignored;
    };
    menuAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    menuAnim.dispose();
    editingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveBreakpoints.of(context).isMobile;
    return Scaffold(
      backgroundColor: AppUi.background,
      body: SafeArea(
        left: false,
        child: Column(
          children: [
            if (isMobile) mobileHeader(context) else desktopHeader(context),
            Expanded(child: messageArea()),
            composer(isMobile),
          ],
        ),
      ),
    );
  }

  void showQrCode() {
    Get.dialog(ShowQRPage(port: ChatService.port));
  }

  void showJoinDialog() {
    Get.dialog(const JoinChat());
  }

  void showMoreMenu(BuildContext context) {
    Get.dialog(
      HeaderMenu(
        offset: Offset(MediaQuery.of(context).size.width, 64),
      ),
    );
  }

  Widget onlineSummary({required bool compact}) {
    return GetBuilder<DeviceController>(
      builder: (deviceController) {
        final int online = deviceController.availableDevice();
        String text = '还没有设备在线';
        if (online > 0) {
          text = compact ? '$online 台设备在线' : '$online 台设备在线，消息和文件会发给所有在线设备';
        }
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: online > 0 && compact ? AppUi.onlineText : AppUi.textSecondary,
          ),
        );
      },
    );
  }

  Widget desktopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AppUi.surface,
        border: Border(bottom: BorderSide(color: AppUi.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 窗口比较窄时按钮只留图标
          final bool compact = constraints.maxWidth < 620;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.allDevices,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppUi.text, height: 1.4),
                    ),
                    onlineSummary(compact: false),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (compact) ...[
                UiIconButton(
                  icon: Icons.qr_code_2_rounded,
                  tooltip: '显示本机二维码',
                  outlined: true,
                  onPressed: showQrCode,
                ),
                const SizedBox(width: 8),
                UiIconButton(
                  icon: Icons.link_rounded,
                  tooltip: '输入地址连接',
                  outlined: true,
                  onPressed: showJoinDialog,
                ),
              ] else ...[
                UiButton(
                  label: '二维码',
                  icon: Icons.qr_code_2_rounded,
                  onPressed: showQrCode,
                ),
                const SizedBox(width: 8),
                UiButton(
                  label: '输入地址连接',
                  icon: Icons.link_rounded,
                  onPressed: showJoinDialog,
                ),
              ],
              const SizedBox(width: 8),
              UiIconButton(
                icon: Icons.more_vert_rounded,
                tooltip: '更多',
                outlined: true,
                onPressed: () => showMoreMenu(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget mobileHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppUi.surface,
        border: Border(bottom: BorderSide(color: AppUi.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.allDevices,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppUi.text, height: 1.35),
                      ),
                      onlineSummary(compact: true),
                    ],
                  ),
                ),
                if (ScanUtil.isSupported)
                  UiIconButton(
                    icon: Icons.qr_code_scanner_rounded,
                    tooltip: l10n.scan,
                    size: 44,
                    iconSize: 22,
                    onPressed: ScanUtil.parseScan,
                  ),
                UiIconButton(
                  icon: Icons.qr_code_2_rounded,
                  tooltip: '显示本机二维码',
                  size: 44,
                  iconSize: 22,
                  onPressed: showQrCode,
                ),
                UiIconButton(
                  icon: Icons.more_vert_rounded,
                  tooltip: '更多',
                  size: 44,
                  iconSize: 22,
                  onPressed: () => showMoreMenu(context),
                ),
              ],
            ),
          ),
          const _DeviceStrip(),
        ],
      ),
    );
  }

  Widget messageArea() {
    return GestureDetector(
      onTap: () {
        focusNode.unfocus();
      },
      child: GetBuilder<DeviceController>(
        builder: (deviceController) {
          return GetBuilder<ChatController>(
            builder: (_) {
              List<Widget?> children = [];
              if (chatController.backup.isNotEmpty) {
                children = chatController.backup;
              } else {
                children = chatController.messageItems;
              }
              if (children.isEmpty) {
                final int online = deviceController.availableDevice();
                if (online == 0) {
                  return const ConnectGuide();
                }
                return emptyHint(online);
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                controller: chatController.scrollController,
                itemCount: children.length,
                cacheExtent: 99999,
                itemBuilder: (c, i) {
                  return children[i];
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget emptyHint(int online) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppUi.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.forum_outlined, color: AppUi.accentText),
            ),
            const SizedBox(height: 12),
            Text(
              '已连上 $online 台设备',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppUi.text),
            ),
            const SizedBox(height: 4),
            Text(
              GetPlatform.isDesktop ? '发条消息，或者把文件拖进窗口试试' : '发条消息，或者点左下角的加号发文件',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppUi.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void sendText() {
    if (editingController.text.isEmpty) {
      return;
    }
    chatController.sendTextMessage(editingController.text);
    editingController.clear();
  }

  void toggleAttachMenu() {
    if (menuAnim.status == AnimationStatus.completed || menuAnim.status == AnimationStatus.forward) {
      menuAnim.reverse();
    } else {
      menuAnim.forward();
    }
  }

  Widget composer(bool isMobile) {
    final double side = isMobile ? 12 : 24;
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 8, side, isMobile ? 10 : 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          attachMenu(),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppUi.surface,
              border: Border.all(color: AppUi.borderStrong),
              borderRadius: BorderRadius.circular(isMobile ? 27 : 14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                attachButton(isMobile),
                const SizedBox(width: 6),
                Expanded(child: inputField(isMobile)),
                const SizedBox(width: 6),
                sendButton(isMobile),
              ],
            ),
          ),
          if (!isMobile)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                '也可以直接把文件或文件夹拖进窗口发送',
                style: TextStyle(fontSize: 12, color: AppUi.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget attachButton(bool isMobile) {
    final BorderRadius radius = BorderRadius.circular(isMobile ? 22 : 10);
    return Tooltip(
      message: '发送图片、视频、文件或文件夹',
      child: Material(
        color: AppUi.subtle,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: toggleAttachMenu,
          child: SizedBox(
            width: 44,
            height: 44,
            child: AnimatedBuilder(
              animation: menuAnim,
              builder: (c, child) {
                return Transform.rotate(
                  angle: menuAnim.value * pi / 4,
                  child: child,
                );
              },
              child: const Icon(Icons.add_rounded, size: 22, color: AppUi.text),
            ),
          ),
        ),
      ),
    );
  }

  Widget inputField(bool isMobile) {
    return TextField(
      focusNode: focusNode,
      controller: editingController,
      autofocus: false,
      maxLines: 8,
      minLines: 1,
      keyboardType: GetPlatform.isDesktop ? TextInputType.text : TextInputType.multiline,
      style: const TextStyle(fontSize: 14.5, color: AppUi.text, height: 1.45),
      decoration: InputDecoration(
        hintText: isMobile ? '输入消息' : '输入消息，Enter 发送，Shift + Enter 换行',
        hintStyle: const TextStyle(fontSize: 14.5, color: AppUi.placeholder),
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      ),
      onSubmitted: (_) {
        if (inputMultiline) {
          // 如果切换到多行模式，按下回车仅仅是换行，不发送消息
          editingController.value = TextEditingValue(
            text: '${editingController.text}\n',
          );
          focusNode.requestFocus();
          return;
        }
        sendText();
        // 发完焦点留在输入框里，可以接着打字
        focusNode.requestFocus();
      },
    );
  }

  Widget sendButton(bool isMobile) {
    if (isMobile) {
      return Material(
        color: hasInput ? AppUi.accent : AppUi.subtle,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: hasInput ? sendText : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.send_rounded,
              size: 20,
              color: hasInput ? Colors.white : AppUi.textSecondary,
            ),
          ),
        ),
      );
    }
    return UiButton(
      label: '发送',
      icon: Icons.send_rounded,
      variant: UiButtonVariant.filled,
      height: 44,
      onPressed: hasInput ? sendText : null,
    );
  }

  Widget attachMenu() {
    return SizeTransition(
      sizeFactor: menuAnim,
      axisAlignment: -1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            attachTile(Icons.image_outlined, '图片', pickImages),
            attachTile(Icons.movie_outlined, '视频', pickVideos),
            Tooltip(
              message: l10n.systemManagerTips,
              child: attachTile(Icons.insert_drive_file_outlined, '文件', pickFiles),
            ),
            Tooltip(
              message: l10n.systemManagerTips,
              child: attachTile(Icons.folder_outlined, '文件夹', pickDirectory),
            ),
          ],
        ),
      ),
    );
  }

  Widget attachTile(IconData icon, String label, Future<void> Function() action) {
    return Material(
      color: AppUi.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppUi.border),
      ),
      child: InkWell(
        onTap: () {
          menuAnim.reverse();
          Future.delayed(const Duration(milliseconds: 100), action);
        },
        child: SizedBox(
          width: 84,
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: AppUi.accent),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppUi.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> photos = await picker.pickMultiImage();
    for (var photo in photos) {
      chatController.sendFileMessageByPath(photo.path);
    }
  }

  Future<void> pickVideos() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> videos = await picker.pickMultiVideo();
    for (var video in videos) {
      chatController.sendFileMessageByPath(video.path);
    }
  }

  Future<void> pickFiles() async {
    if (GetPlatform.isDesktop || GetPlatform.isWeb) {
      List<XFile>? files = await getFilesForDesktopAndWeb();
      if (files == null) {
        return;
      }
      chatController.sendFileMessageByXFiles(files);
    } else if (GetPlatform.isAndroid) {
      // 选择文件路径
      List<String?> filePaths = await getFilesPathsForAndroid(true);
      Log.i('filePaths -> $filePaths');
      if (filePaths.isEmpty) {
        return;
      }
      for (String? filePath in filePaths) {
        Log.v(filePath);
        if (filePath == null) {
          return;
        }
        chatController.sendFileMessageByPath(filePath);
      }
    }
  }

  Future<void> pickDirectory() async {
    String? dirPath;
    if (GetPlatform.isDesktop) {
      dirPath = await getDirectoryPath(confirmButtonText: l10n.select);
    } else {
      dirPath = await file_manager.FileManager.selectDirectory();
    }
    Log.d('dirPath -> $dirPath');
    if (dirPath == null) {
      return;
    }
    chatController.sendDirMessageByPath(dirPath);
  }
}

/// 手机布局里显示已连接设备的一排标签
class _DeviceStrip extends StatelessWidget {
  const _DeviceStrip();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DeviceController>(
      builder: (deviceController) {
        final List<Device> devices = deviceController.connectDevice;
        if (devices.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            itemCount: devices.length,
            separatorBuilder: (context, i) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final Device device = devices[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppUi.surface,
                  border: Border.all(color: device.isAlive ? AppUi.borderStrong : AppUi.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UiStatusDot(online: device.isAlive),
                    const SizedBox(width: 6),
                    Text(
                      device.deviceName ?? uiDeviceLabel(device.deviceType),
                      style: TextStyle(
                        fontSize: 13,
                        color: device.isAlive ? AppUi.text : AppUi.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
