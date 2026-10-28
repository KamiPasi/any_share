import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/modules/dialog/join_chat.dart';
import 'package:speed_share/services/services.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/utils/lan_address.dart';
import 'package:speed_share/utils/scan_util.dart';
import 'package:speed_share/widgets/ui_kit.dart';

/// 还没有设备在线、也没有消息时，消息区显示的连接引导
class ConnectGuide extends StatefulWidget {
  const ConnectGuide({super.key});

  @override
  State<ConnectGuide> createState() => _ConnectGuideState();
}

class _ConnectGuideState extends State<ConnectGuide> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<LanAddressController>(
      builder: (controller) => guide(controller),
    );
  }

  Widget guide(LanAddressController controller) {
    final List<LanAddress> addresses = controller.addresses;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '把另一台设备连进来',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppUi.text, height: 1.35),
              ),
              const SizedBox(height: 4),
              const Text(
                '两台设备要在同一个局域网里，比如连着同一个 Wi-Fi，或者都在公司内网。',
                style: TextStyle(fontSize: 14, color: AppUi.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 18),
              if (addresses.length > 1) ...[
                UiAddressSelector(
                  addresses: addresses,
                  selected: controller.selectedIndex,
                  onChanged: controller.select,
                ),
                const SizedBox(height: 16),
              ],
              addressCards(controller),
              const SizedBox(height: 16),
              appCard(),
              const SizedBox(height: 14),
              tip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget addressCards(LanAddressController controller) {
    final LanAddress? address = controller.selected;
    if (!controller.loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (address == null) {
      return const UiCard(
        radius: 16,
        padding: EdgeInsets.all(20),
        child: Text(
          '没有找到局域网地址，先连上 Wi-Fi 或网线再试。',
          style: TextStyle(fontSize: 14, color: AppUi.textSecondary),
        ),
      );
    }
    final String url = address.url(ChatService.port);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              scanCard(url, constraints.maxWidth < 420),
              const SizedBox(height: 16),
              browserCard(url),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: scanCard(url, false)),
            const SizedBox(width: 16),
            Expanded(child: browserCard(url)),
          ],
        );
      },
    );
  }

  Widget scanCard(String url, bool narrow) {
    return UiCard(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppUi.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: QrImageView(
              data: url,
              size: narrow ? 108 : 132,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '扫码连接',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppUi.text),
                ),
                SizedBox(height: 6),
                Text(
                  '对方用速享 App 的扫一扫可以直接连上；没装 App 的话用手机相机扫，会在浏览器里打开网页版。',
                  style: TextStyle(fontSize: 13, color: AppUi.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget browserCard(String url) {
    return UiCard(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '浏览器打开',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppUi.text),
          ),
          const SizedBox(height: 6),
          const Text(
            '别的电脑、平板不用装软件，在浏览器地址栏输入：',
            style: TextStyle(fontSize: 13, color: AppUi.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          UiCopyField(text: url),
          const SizedBox(height: 12),
          const Text(
            '打开的是网页版速享，一样能收发文字和文件。',
            style: TextStyle(fontSize: 12, color: AppUi.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget appCard() {
    final List<Widget> actions = [
      if (ScanUtil.isSupported)
        UiButton(
          label: '扫一扫',
          icon: Icons.qr_code_scanner_rounded,
          variant: UiButtonVariant.soft,
          onPressed: ScanUtil.parseScan,
        ),
      UiButton(
        label: '输入地址连接',
        icon: Icons.link_rounded,
        onPressed: () => Get.dialog(const JoinChat()),
      ),
    ];
    final Widget info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppUi.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.wifi_rounded, size: 20, color: AppUi.accentText),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '对方也装了速享',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppUi.text),
              ),
              SizedBox(height: 2),
              Text(
                '在同一个局域网里打开速享，两边会自动连上。没连上就点「输入地址连接」，填对方速享里显示的本机地址。',
                style: TextStyle(fontSize: 13, color: AppUi.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
    return UiCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              for (final Widget action in actions) ...[
                const SizedBox(width: 10),
                action,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget tip() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline_rounded, size: 16, color: AppUi.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            GetPlatform.isWindows ? '还是连不上的话，确认两台设备在同一个网络里，再看看 Windows 防火墙有没有放行速享。' : '还是连不上的话，确认两台设备在同一个网络里。',
            style: const TextStyle(fontSize: 12, color: AppUi.textSecondary, height: 1.5),
          ),
        ),
      ],
    );
  }
}
