import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speed_share/generated/l10n.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({Key? key}) : super(key: key);

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  // 同一个二维码会被连续很多帧识别到，只返回一次，否则会多关掉后面的页面
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 相机打不开时页面是空白的，要留一个返回的地方
      appBar: AppBar(title: Text(l10n.scan)),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          for (final barcode in capture.barcodes) {
            final String? code = barcode.rawValue;
            if (code == null) continue;
            _done = true;
            debugPrint('Barcode found! $code');
            Get.back(result: code);
            return;
          }
        },
      ),
    );
  }
}
