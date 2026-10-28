import 'dart:io';

import 'package:speed_share/common/config.dart';

/// 本机的一个局域网地址，name 是网卡名，比如「以太网」「WLAN」
class LanAddress {
  const LanAddress(this.name, this.ip);

  final String name;
  final String ip;

  /// 「地址:端口」，端口传 ChatService.port。服务还没启动时它是 0 或 null，这时用默认端口
  String hostPort(int? port) {
    final int value = port == null || port == 0 ? Config.chatPortRangeStart : port;
    return '$ip:$value';
  }

  String url(int? port) => 'http://${hostPort(port)}';
}

// 虚拟网卡（WSL、Hyper-V、虚拟机、Docker、组网工具）的地址别的设备一般连不上，排到后面
const List<String> _virtualKeywords = [
  'vethernet',
  'virtual',
  'vmware',
  'vbox',
  'hyper-v',
  'wsl',
  'docker',
  'tailscale',
  'zerotier',
  'virbr',
  'veth',
  'br-',
];

bool _isVirtual(String name) {
  final String lower = name.toLowerCase();
  return _virtualKeywords.any((keyword) => lower.contains(keyword));
}

/// 列出别的设备可以用来连接本机的 IPv4 地址，物理网卡排在前面。
///
/// 以前直接把所有地址都拿来生成二维码，里面有 IPv6 和回环地址，扫出来是连不上的。
Future<List<LanAddress>> lanAddresses() async {
  final List<LanAddress> physical = [];
  final List<LanAddress> virtual = [];
  try {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final NetworkInterface netInterface in interfaces) {
      for (final InternetAddress address in netInterface.addresses) {
        if (address.isLoopback || address.address.startsWith('169.254.')) {
          continue;
        }
        final LanAddress item = LanAddress(netInterface.name, address.address);
        if (_isVirtual(netInterface.name)) {
          virtual.add(item);
        } else {
          physical.add(item);
        }
      }
    }
  } catch (e) {
    // 拿不到网卡信息时（比如网页版）就当没有地址
  }
  return [...physical, ...virtual];
}
