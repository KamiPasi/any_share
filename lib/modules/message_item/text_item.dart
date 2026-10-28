import 'package:flutter/material.dart';

import 'package:speed_share/models/models.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/widgets/ui_kit.dart';

class TextMessageItem extends StatelessWidget {
  final TextMessage? info;
  final bool? sendByUser;

  const TextMessageItem({Key? key, this.info, this.sendByUser}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final bool mine = sendByUser!;
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: UiBubble(
              sendByUser: mine,
              child: SelectableText(
                info!.content!,
                style: const TextStyle(
                  color: AppUi.text,
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
        // 别的设备发来的文字可以一键复制
        if (!mine)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: UiIconButton(
              icon: Icons.content_copy_rounded,
              tooltip: '复制',
              size: 32,
              iconSize: 16,
              color: AppUi.textSecondary,
              onPressed: () => uiCopy(info!.content ?? '', message: '已复制'),
            ),
          ),
      ],
    );
  }
}
