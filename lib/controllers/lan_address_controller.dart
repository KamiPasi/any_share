import 'package:get/get.dart';

import 'package:speed_share/utils/lan_address.dart';
import 'device_controller.dart';

/// 本机的局域网地址，以及当前用哪一个给别的设备连接。
///
/// 侧栏「这台电脑」、二维码弹窗、连接引导、设置页都从这里取地址，
/// 在任何一处切换网卡，其他地方跟着变，下次打开也还是它。
class LanAddressController extends GetxController {
  List<LanAddress> addresses = [];
  bool loaded = false;
  int _selected = -1;

  int get selectedIndex => _selected;

  LanAddress? get selected => _selected < 0 ? null : addresses[_selected];

  @override
  void onInit() {
    super.onInit();
    refreshAddresses();
  }

  /// 重新读网卡，插拔网线、开关 VPN 之后地址会变
  Future<void> refreshAddresses() async {
    final String? keep = selected?.ip;
    addresses = await lanAddresses();
    loaded = true;
    final int index = keep == null ? -1 : addresses.indexWhere((e) => e.ip == keep);
    _selected = index >= 0 ? index : preferredLanAddressIndex(addresses);
    update();
  }

  Future<void> select(int index) async {
    if (index < 0 || index >= addresses.length || index == _selected) {
      return;
    }
    _selected = index;
    saveLanAddress(addresses[index]);
    update();
    // 发给其他设备的地址列表也把选中的排到最前面，对方挨个探测时能少等几秒
    final DeviceController deviceController = Get.find();
    deviceController.addrs = await DeviceController.localAddress();
  }
}
