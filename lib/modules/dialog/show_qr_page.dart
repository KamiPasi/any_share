import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/services/services.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/utils/lan_address.dart';
import 'package:speed_share/widgets/ui_kit.dart';

// 展示二维码的弹窗
class ShowQRPage extends StatefulWidget {
  const ShowQRPage({Key? key, this.port}) : super(key: key);
  final int? port;

  @override
  State<ShowQRPage> createState() => _ShowQRPageState();
}

class _ShowQRPageState extends State<ShowQRPage> {
  List<LanAddress> addresses = [];
  int selected = 0;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    lanAddresses().then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        addresses = value;
        loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: AppUi.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '扫码连接这台设备',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppUi.text),
                        ),
                      ),
                      UiIconButton(
                        icon: Icons.close_rounded,
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '用速享 App 的扫一扫，或者手机相机扫码后在浏览器里打开。',
                          style: TextStyle(fontSize: 13, color: AppUi.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        content(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget content() {
    if (!loaded) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (addresses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          '没有找到局域网地址，先连上 Wi-Fi 或网线再试。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppUi.textSecondary),
        ),
      );
    }
    final String url = addresses[selected].url(widget.port ?? ChatService.port);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (addresses.length > 1) ...[
          UiAddressSelector(
            addresses: addresses,
            selected: selected,
            onChanged: (i) => setState(() => selected = i),
          ),
          const SizedBox(height: 16),
        ],
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppUi.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: QrImageView(
              data: url,
              size: 220,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        UiCopyField(text: url),
      ],
    );
  }
}
