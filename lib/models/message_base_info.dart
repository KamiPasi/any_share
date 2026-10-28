import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:speed_share/common/device_type.dart';

import 'browser_file_message.dart';
import 'clipboard_message.dart';
import 'dir_message.dart';
import 'file_message.dart';
import 'join_message.dart';
import 'notify_message.dart';
import 'text_message.dart';

part 'message_base_info.g.dart';

@JsonSerializable()
class MessageBaseInfo {
  MessageBaseInfo({
    this.msgType,
    this.deviceName = '',
    this.deviceType,
    this.deviceId,
  });

  factory MessageBaseInfo.resolveMessage(Map<String, dynamic> json) {
    String? msgType = json['msgType'];
    switch (msgType) {
      case 'file':
        return FileMessage.fromJson(json);
      case 'text':
        return TextMessage.fromJson(json);
      case 'dir':
        return DirMessage.fromJson(json);
      case 'dirPart':
        return DirPartMessage.fromJson(json);
      case 'clip':
        return ClipboardMessage.fromJson(json);
      case 'webfile':
        return BrowserFileMessage.fromJson(json);
      case 'notify':
        return NotifyMessage.fromJson(json);
      case 'join':
        return JoinMessage.fromJson(json);
    }
    throw Exception('Unknown message type: $msgType');
  }

  /// 消息类型
  /// Message Type
  String? msgType;

  /// 发送设备的名称
  /// The name of the sending device
  String? deviceName;

  /// 用来做发送设备的唯一标识
  /// Used as a unique identifier for the sending device
  String? deviceId;

  /// 设备类型
  /// Device Type

  @DeviceTypeConverter()
  DeviceType? deviceType;

  factory MessageBaseInfo.fromJson(Map<String, dynamic> json) => _$MessageBaseInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MessageBaseInfoToJson(this);

  @override
  String toString() {
    return json.encode(this);
  }
}

/// 设备类型按枚举名传输。旧版协议（包括内置的网页端）传的是整数，
/// 对应旧版 lib/global/constant.dart 里的 phone = 0、desktop = 1、web = 2
class DeviceTypeConverter implements JsonConverter<DeviceType?, Object?> {
  const DeviceTypeConverter();

  @override
  DeviceType? fromJson(Object? json) {
    if (json == null) return null;
    if (json is int) {
      return switch (json) {
        0 => DeviceType.android,
        1 => DeviceType.windows,
        2 => DeviceType.browser,
        _ => DeviceType.unknown,
      };
    }

    return DeviceType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => DeviceType.unknown,
    );
  }

  @override
  String? toJson(DeviceType? object) => object?.name;
}
