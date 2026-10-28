import 'package:flutter/material.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/models/models.dart';
import 'package:speed_share/modules/message_item/text_item.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/widgets/ui_kit.dart';
import 'broswer_file_item.dart';
import 'dir_item.dart';
import 'file_item.dart';

class MessageItemFactory {
  // TODO: Use extension
  static Widget? getMessageItem(MessageBaseInfo? info, bool sendByUser, BuildContext context) {
    Widget? child;
    if (info is TextMessage) {
      child = TextMessageItem(
        info: info,
        sendByUser: sendByUser,
      );
    } else if (info is FileMessage) {
      child = FileItem(
        info: info,
        sendByUser: sendByUser,
      );
    } else if (info is DirMessage) {
      child = DirMessageItem(
        info: info,
        sendByUser: sendByUser,
      );
    } else if (info is BrowserFileMessage) {
      child = BroswerFileItem(
        info: info,
        sendByUser: sendByUser,
      );
    }
    if (child == null) {
      return null;
    }
    final MessageBaseInfo message = info!;
    final Widget content = child;
    return Builder(
      builder: (context) {
        // 别的设备发来的消息在气泡上方显示设备名，剪切板消息另外标出来
        String sender = message.deviceName ?? '';
        if (message is ClipboardMessage) {
          sender = sender.isEmpty ? l10n.clipboard : '$sender · ${l10n.clipboard}';
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: sendByUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!sendByUser) ...[
                UiDeviceAvatar(type: message.deviceType, size: 32),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: sendByUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!sendByUser && sender.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          sender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppUi.textSecondary),
                        ),
                      ),
                    content,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
