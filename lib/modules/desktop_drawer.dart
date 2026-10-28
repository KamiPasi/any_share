import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:speed_share/common/common.dart';
import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/routes/app_pages.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/services/services.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/utils/lan_address.dart';
import 'package:speed_share/widgets/ui_kit.dart';
import 'dialog/show_qr_page.dart';

/// 宽窗口左边的侧栏：导航、设备列表和本机地址
class DesktopDrawer extends StatefulWidget {
  const DesktopDrawer({
    Key? key,
    required this.value,
    this.onChange,
  }) : super(key: key);

  final String value;
  final void Function(String value)? onChange;

  @override
  State<DesktopDrawer> createState() => _DesktopDrawerState();
}

class _DesktopDrawerState extends State<DesktopDrawer> {
  List<LanAddress> addresses = [];

  @override
  void initState() {
    super.initState();
    lanAddresses().then((value) {
      if (mounted) {
        setState(() => addresses = value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width < 900 ? 228 : 260;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppUi.surface,
        border: Border(right: BorderSide(color: AppUi.border)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              brand(),
              const SizedBox(height: 20),
              navItem(Icons.chat_bubble_outline_rounded, '消息', AppPages.home),
              const SizedBox(height: 2),
              navItem(Icons.tune_rounded, l10n.setting, AppPages.setting),
              const SizedBox(height: 20),
              Expanded(child: devices()),
              const SizedBox(height: 12),
              thisDevice(),
            ],
          ),
        ),
      ),
    );
  }

  Widget brand() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppUi.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.share_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '速享',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppUi.text, height: 1.3),
                ),
                Text(
                  '局域网文件与文字互传',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppUi.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget navItem(IconData icon, String label, String value) {
    final bool selected = widget.value == value;
    final Color color = selected ? AppUi.accentText : AppUi.textMuted;
    return Material(
      color: selected ? AppUi.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onChange?.call(value),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget devices() {
    return GetBuilder<DeviceController>(
      builder: (deviceController) {
        final List<Device> list = deviceController.connectDevice;
        final int online = deviceController.availableDevice();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.device,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppUi.textSecondary),
                    ),
                  ),
                  Text(
                    '$online 台在线',
                    style: TextStyle(fontSize: 12, color: online > 0 ? AppUi.onlineText : AppUi.textSecondary),
                  ),
                ],
              ),
            ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '还没有设备连进来，连上的设备会显示在这里。',
                  style: TextStyle(fontSize: 12, color: AppUi.textSecondary, height: 1.6),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: list.length,
                  itemBuilder: (context, i) => deviceRow(list[i]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget deviceRow(Device device) {
    final bool alive = device.isAlive;
    final String type = uiDeviceLabel(device.deviceType);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          UiDeviceAvatar(type: device.deviceType, dimmed: !alive),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  device.deviceName ?? type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: alive ? AppUi.text : AppUi.textMuted,
                  ),
                ),
                Row(
                  children: [
                    UiStatusDot(online: alive, size: 6),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        alive ? '在线 · $type' : '离线 · $type',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: alive ? AppUi.onlineText : AppUi.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget thisDevice() {
    final LanAddress? address = addresses.isEmpty ? null : addresses.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUi.surfaceMuted,
        border: Border.all(color: AppUi.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.computer_rounded, size: 16, color: AppUi.textSecondary),
              const SizedBox(width: 8),
              Text(
                GetPlatform.isDesktop ? '这台电脑' : '这台设备',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppUi.text),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (address == null)
            const Text(
              '没有找到局域网地址，先连上 Wi-Fi 或网线。',
              style: TextStyle(fontSize: 12, color: AppUi.textSecondary, height: 1.5),
            )
          else ...[
            SelectableText(
              '${address.ip}:${ChatService.port}',
              style: AppUi.mono(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              '${address.name} · 其他设备用这个地址连接',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppUi.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: UiButton(
                  label: '二维码',
                  icon: Icons.qr_code_2_rounded,
                  variant: UiButtonVariant.filled,
                  dense: true,
                  height: 36,
                  onPressed: () => Get.dialog(ShowQRPage(port: ChatService.port)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: UiButton(
                  label: '复制',
                  icon: Icons.content_copy_rounded,
                  dense: true,
                  height: 36,
                  onPressed: address == null ? null : () => uiCopy(address.url(ChatService.port)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
