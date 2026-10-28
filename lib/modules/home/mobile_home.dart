import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/modules/personal/setting/setting_page.dart';
import 'package:speed_share/modules/share_chat_window.dart';
import 'package:speed_share/themes/app_ui.dart';

class MobileHome extends StatefulWidget {
  const MobileHome({Key? key}) : super(key: key);

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUi.background,
      body: SafeArea(
        bottom: false,
        child: PageTransitionSwitcher(
          transitionBuilder:
              (
                Widget child,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return FadeThroughTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                );
              },
          child: [
            const ShareChatV2(),
            const SettingPage(),
          ][page],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppUi.border)),
        ),
        child: NavigationBar(
          height: 64,
          elevation: 0,
          selectedIndex: page,
          backgroundColor: AppUi.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppUi.accentSoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            page = index;
            setState(() {});
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppUi.accentText),
              label: '消息',
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_rounded),
              selectedIcon: const Icon(Icons.tune_rounded, color: AppUi.accentText),
              label: l10n.setting,
            ),
          ],
        ),
      ),
    );
  }
}
