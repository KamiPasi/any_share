import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/common/common.dart';
import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/widgets/ui_kit.dart';

class JoinChat extends StatefulWidget {
  const JoinChat({Key? key}) : super(key: key);

  @override
  State createState() => _JoinChatState();
}

class _JoinChatState extends State<JoinChat> {
  TextEditingController controller = TextEditingController(
    text: '',
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: AppUi.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '输入对方的地址',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppUi.text),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '填对方速享里显示的本机地址，比如 192.168.1.23:12000',
                    style: TextStyle(fontSize: 13, color: AppUi.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (_) {
                      joinChat();
                    },
                    style: AppUi.mono(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.23:12000',
                      hintStyle: AppUi.mono(fontSize: 14, color: AppUi.placeholder),
                      filled: true,
                      fillColor: AppUi.field,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppUi.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppUi.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      UiButton(
                        label: '取消',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      UiButton(
                        label: l10n.join,
                        variant: UiButtonVariant.filled,
                        onPressed: joinChat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> joinChat() async {
    // todo
    if (controller.text.isEmpty) {
      showToast('URL不能为空');
      return;
    }
    String url = controller.text;
    if (!url.startsWith('http://')) {
      url = 'http://$url';
    }
    if (!url.endsWith(':${Config.chatPortRangeStart}')) {
      url = '$url:${Config.chatPortRangeStart}';
    }
    Get.back();
    Log.i('SendJoinEvent : $url');
    ChatController chatController = Get.find();
    chatController.sendJoinMessageByUrl(url);
  }
}
