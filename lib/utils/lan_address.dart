import 'dart:io';

import 'package:settings/settings.dart';
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

// 虚拟网卡（虚拟机、WSL、Docker、代理工具的 TUN、VPN、组网工具）的地址别的设备一般连不上，排到后面。
// 「Meta」是 Clash Meta（mihomo）开 TUN 模式时建的网卡
const List<String> _virtualKeywords = [
  'vethernet',
  'virtual',
  'vmware',
  'vmnet',
  'vbox',
  'hyper-v',
  'wsl',
  'docker',
  'tailscale',
  'zerotier',
  'virbr',
  'veth',
  'br-',
  'meta',
  'clash',
  'mihomo',
  'tun',
  'tap',
  'wireguard',
  'vpn',
  'npcap',
  'loopback',
  'bluetooth',
  '蓝牙',
  'radmin',
  'hamachi',
];

// 实体网卡常见的名字开头
const List<String> _physicalPrefixes = [
  '以太网',
  '无线',
  'wlan',
  'wi-fi',
  'wifi',
  'ethernet',
  'eth',
  'en',
  'wl',
];

bool _isVirtual(String name) {
  final String lower = name.toLowerCase();
  return _virtualKeywords.any((keyword) => lower.contains(keyword));
}

bool _isPhysical(String name) {
  final String lower = name.toLowerCase();
  return _physicalPrefixes.any((prefix) => lower.startsWith(prefix));
}

/// 地址段的优先级，越小越像真正的局域网
int _rangeRank(String ip) {
  final List<int> parts = ip.split('.').map((e) => int.tryParse(e) ?? -1).toList();
  if (parts.length != 4) {
    return 9;
  }
  // 198.18.0.0/15 是测试网段，Clash 之类的代理工具的 TUN 网卡和 fake-ip 用它；
  // 100.64.0.0/10 是运营商级 NAT，Tailscale 也用它
  if (parts[0] == 198 && (parts[1] == 18 || parts[1] == 19)) {
    return 8;
  }
  if (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127) {
    return 8;
  }
  if (parts[0] == 192 && parts[1] == 168) {
    return 0;
  }
  if (parts[0] == 10) {
    return 1;
  }
  if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) {
    return 2;
  }
  return 5;
}

int _rank(LanAddress address) {
  int rank = _rangeRank(address.ip) * 10;
  if (_isVirtual(address.name)) {
    rank += 100;
  } else if (_isPhysical(address.name)) {
    rank -= 5;
  }
  return rank;
}

/// 列出别的设备可以用来连接本机的 IPv4 地址，最像真实局域网的排在前面。
///
/// 以前直接把所有地址都拿来生成二维码，里面有 IPv6 和回环地址，扫出来是连不上的。
Future<List<LanAddress>> lanAddresses() async {
  final List<LanAddress> list = [];
  try {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final NetworkInterface netInterface in interfaces) {
      for (final InternetAddress address in netInterface.addresses) {
        if (address.isLoopback || address.address.startsWith('169.254.')) {
          continue;
        }
        list.add(LanAddress(netInterface.name, address.address));
      }
    }
  } catch (e) {
    // 拿不到网卡信息时就当没有地址
  }
  // List.sort 不保证稳定，排名相同的保持系统给的顺序
  final List<int> order = List.generate(list.length, (i) => i);
  order.sort((a, b) {
    final int diff = _rank(list[a]) - _rank(list[b]);
    return diff != 0 ? diff : a - b;
  });
  return [for (final int i in order) list[i]];
}

final Setting _savedName = 'lanAddressName'.setting;
final Setting _savedIp = 'lanAddressIp'.setting;

/// 记住用户选的网卡，下次打开还选它
void saveLanAddress(LanAddress address) {
  _savedName.set(address.name);
  _savedIp.set(address.ip);
}

/// 用户上次选的地址在不在列表里：先按 IP 找，IP 变了（比如重新拨号）再按网卡名找，都没有就用排第一的
int preferredLanAddressIndex(List<LanAddress> list) {
  if (list.isEmpty) {
    return -1;
  }
  final Object? ip = _savedIp.get();
  final Object? name = _savedName.get();
  int index = list.indexWhere((e) => e.ip == ip);
  if (index < 0) {
    index = list.indexWhere((e) => e.name == name);
  }
  return index < 0 ? 0 : index;
}
