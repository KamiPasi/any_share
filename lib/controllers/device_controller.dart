import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/common/common.dart';
import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/models/history.dart';
import 'package:speed_share/services/dio_service.dart';
import 'package:speed_share/utils/lan_address.dart';

// 用于管理设备连接的类
class DeviceController extends GetxController {
  DeviceController() {
    // return;
    // TODO
    if (GetPlatform.isWeb) {
      return;
    }
    // Log.i(RuntimeEnvir.filesPath);
    // Directory(RuntimeEnvir.filesPath).list().forEach((element) {
    //   Log.i(element);
    // });
    if (File(historyPath).existsSync()) {
      // 如果文件存在的话
      historys = HistoryMessages.fromJson(json.decode(File(historyPath).readAsStringSync()));
      JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      String prettyprint = encoder.convert(historys);
      Log.i('history cache $prettyprint');
      historys.datas!.removeWhere((element) => element.url!.contains('null'));
      syncHistoryToLocal();
      List<HistoryMessage> newHistorys = [];
      // for (History history in historys.datas!) {
      //   History exist=newHistorys.firstWhere((element) => element.url=)
      // }
      // 向历史连接的设备发送连接消息
      Future.delayed(const Duration(milliseconds: 2000), () {
        historys.datas!.forEach(
          ((element) {
            // TODO
            chatController.sendJoinMessageByUrl(element.url!);
          }),
        );
      });
    }
    checkConnectStat();
    // TODO 开启定时器
    // 检测链接设备是否互通
  }

  late final ChatController chatController = Get.find();

  String deviceName = '';
  String uniqueKey = '';
  late final DeviceType deviceType;
  late List<String> addrs;

  Future<void> init() async {
    uniqueKey = await UniqueUtil.getUniqueKey();
    deviceName = await UniqueUtil.getDevicesId();
    Log.v('deviceId -> $deviceName', 'DeviceService');
    Log.v('uniqueKey -> $uniqueKey', 'DeviceService');
    if (GetPlatform.isAndroid) {
      deviceType = DeviceType.android;
    } else if (GetPlatform.isIOS) {
      deviceType = DeviceType.ios;
    } else if (GetPlatform.isMacOS) {
      deviceType = DeviceType.mac;
    } else if (GetPlatform.isWindows) {
      deviceType = DeviceType.windows;
    } else if (GetPlatform.isLinux) {
      deviceType = DeviceType.linux;
    } else {
      deviceType = DeviceType.unknown;
    }
    addrs = await localAddress();
  }

  /// 发给其他设备的本机地址列表。对方会按顺序逐个探测，连不上的地址每个要等几秒，
  /// 所以局域网 IPv4 地址排在前面，用户在二维码里选的那个排第一
  static Future<List<String>> localAddress() async {
    final List<LanAddress> lan = await lanAddresses();
    final int preferred = preferredLanAddressIndex(lan);
    List<String> address = [
      if (preferred >= 0) lan[preferred].ip,
      for (int i = 0; i < lan.length; i++)
        if (i != preferred) lan[i].ip,
    ];
    final List<NetworkInterface> interfaces = await NetworkInterface.list(type: InternetAddressType.any);
    for (final NetworkInterface netInterface in interfaces) {
      for (final InternetAddress netAddress in netInterface.addresses) {
        if (!address.contains(netAddress.address)) {
          address.add(netAddress.address);
        }
      }
    }
    return address;
  }

  /// 浏览器多久没来取消息就算离线、多久之后从列表里去掉
  static const Duration browserOfflineAfter = Duration(seconds: 10);
  static const Duration browserRemoveAfter = Duration(minutes: 2);

  void checkConnectStat() {
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      // 循环里有 await，期间可能有设备加进来，所以遍历一份拷贝
      for (Device device in List.of(connectDevice)) {
        if (device.deviceType == DeviceType.browser) {
          // 浏览器没有服务器可以 ping，按它最近一次来取消息的时间算在不在线
          final Duration idle = DateTime.now().difference(device.lastSeen ?? DateTime(2000));
          if (idle > browserRemoveAfter) {
            connectDevice.remove(device);
            update();
          } else if (device.isAlive != idle < browserOfflineAfter) {
            device.isAlive = idle < browserOfflineAfter;
            update();
          }
          continue;
        }
        try {
          Response response = await Dio().get('${device.url}:${device.messagePort}/ping');
          Log.d('checkConnectStat response.data : ${response.data}');
          device.isAlive = true;
          update();
        } catch (e) {
          device.isAlive = false;
          device.sendedHistoryMessage = false;
          device.sendedJoinMessage = false;
          update();
        }
      }
    });
  }

  String historyPath = GetPlatform.isWeb ? '' : '${RuntimeEnvir.filesPath}/history';
  HistoryMessages historys = HistoryMessages(datas: []);
  List<Device> connectDevice = [];
  int availableDevice() {
    int count = 0;
    for (Device device in connectDevice) {
      if (device.isAlive) {
        count++;
      }
    }
    return count;
  }

  /// 返回正常连接的设备
  List<Device> availableDevices() {
    List<Device> devices = [];
    for (Device device in connectDevice) {
      if (device.isAlive) {
        devices.add(device);
      }
    }
    return devices;
  }

  void onDeviceConnect(Device device) {
    if (!connectDevice.contains(device)) {
      // 第一次连接该设备
      connectDevice.add(device);
      // 浏览器下次不会在同一个地址等着被连，不记进历史
      if (!GetPlatform.isWeb && device.deviceType != DeviceType.browser) {
        appendHistory(device.deviceName, '${device.url}:${device.messagePort}', device.id);
      }
      Log.i('device : $device');
    }
    update();
  }

  /// 浏览器每次来取消息时调用，第一次来就加进设备列表
  void onBrowserPoll(String id, String name, String address) {
    final int index = connectDevice.indexWhere((device) => device.id == id);
    if (index >= 0) {
      final Device device = connectDevice[index];
      device.lastSeen = DateTime.now();
      if (!device.isAlive) {
        device.isAlive = true;
        update();
      }
      return;
    }
    final Device device = Device(
      id,
      deviceName: name,
      deviceType: DeviceType.browser,
      url: 'http://$address',
    );
    device.lastSeen = DateTime.now();
    onDeviceConnect(device);
  }

  void appendHistory(String? name, String url, String? id) {
    HistoryMessage history = HistoryMessage(
      deviceName: name,
      url: url,
      id: id,
    );
    if (!historys.datas!.contains(history)) {
      // 不包含才添加这行历史
      historys.datas!.add(history);
    } else {
      HistoryMessage exist = historys.datas!.firstWhere((element) => element.id == history.id);
      exist.url = url;
    }
    syncHistoryToLocal();
  }

  void onDeviceClose(String? id) {
    connectDevice.removeWhere((device) => device.id == id);
    update();
  }

  void syncHistoryToLocal() {
    File(historyPath).writeAsString(historys.toString());
  }

  void clear() {
    connectDevice.clear();
    update();
  }

  // void addHistory(String url) {
  //   historys.datas.add(History());
  //   history.add(url);
  //   'history'.set = jsonEncode(history);
  // }

  void sendToAll(Map<String, dynamic> data) async {
    for (Device device in availableDevices()) {
      // 浏览器自己来取消息，不能往它那儿发
      if (device.deviceType == DeviceType.browser) {
        continue;
      }
      send(data, device);
    }
  }

  void send(Map<String, dynamic> data, Device device) async {
    try {
      await DioClient.post('${device.url}:${device.messagePort}', data: data);
    } catch (e) {
      Log.e('send mesage to ${device.url} error : $e');
    }
  }

  /// 判断一个IP是否已经被连接了
  /// 发送连接消息的时候需要的
  bool ipIsConnect(String ip) {
    for (Device device in availableDevices()) {
      Uri? uri = Uri.tryParse(device.url!);
      if (uri?.host == ip) {
        return true;
      }
    }
    return false;
  }

  /// 清除历史
  void clearHistory() {
    historys.datas?.clear();
    update();
    syncHistoryToLocal();
  }
}
