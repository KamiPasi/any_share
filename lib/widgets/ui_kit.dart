import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/common/common.dart';
import 'package:speed_share/generated/l10n.dart';
import 'package:speed_share/themes/app_ui.dart';
import 'package:speed_share/utils/lan_address.dart';

// 新界面里反复用到的小组件，样式和设计稿一致

/// 复制文字并提示
void uiCopy(String text, {String? message}) {
  Clipboard.setData(ClipboardData(text: text));
  showToast(message ?? l10n.copyed);
}

IconData uiDeviceIcon(DeviceType? type) {
  switch (type) {
    case DeviceType.android:
      return Icons.phone_android_rounded;
    case DeviceType.ios:
      return Icons.phone_iphone_rounded;
    case DeviceType.mac:
      return Icons.laptop_mac_rounded;
    case DeviceType.windows:
      return Icons.desktop_windows_rounded;
    case DeviceType.linux:
      return Icons.computer_rounded;
    case DeviceType.browser:
      return Icons.language_rounded;
    default:
      return Icons.devices_other_rounded;
  }
}

String uiDeviceLabel(DeviceType? type) {
  switch (type) {
    case DeviceType.android:
      return 'Android';
    case DeviceType.ios:
      return 'iOS';
    case DeviceType.mac:
      return 'macOS';
    case DeviceType.windows:
      return 'Windows';
    case DeviceType.linux:
      return 'Linux';
    case DeviceType.browser:
      return '浏览器';
    default:
      return '其他设备';
  }
}

/// 白底描边的卡片，里面的 InkWell 水波纹能正常显示
class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppUi.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppUi.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

enum UiButtonVariant { filled, outline, soft }

/// 文字按钮，可以带图标
class UiButton extends StatelessWidget {
  const UiButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = UiButtonVariant.outline,
    this.height = 40,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final UiButtonVariant variant;
  final double height;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    Color background = AppUi.surface;
    Color foreground = AppUi.text;
    BorderSide side = const BorderSide(color: AppUi.borderStrong);
    if (variant == UiButtonVariant.filled) {
      background = AppUi.accent;
      foreground = Colors.white;
      side = BorderSide.none;
    } else if (variant == UiButtonVariant.soft) {
      background = AppUi.accentSoft;
      foreground = AppUi.accentText;
      side = BorderSide.none;
    }
    final bool enabled = onPressed != null;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: AppUi.subtle,
        disabledForegroundColor: AppUi.textSecondary,
        minimumSize: Size(0, height),
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? 9 : 10),
          side: enabled ? side : BorderSide.none,
        ),
        textStyle: TextStyle(
          fontSize: dense ? 13 : 14,
          fontWeight: variant == UiButtonVariant.outline ? FontWeight.w500 : FontWeight.w600,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 16 : 18),
            SizedBox(width: dense ? 6 : 8),
          ],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// 只有图标的按钮，鼠标悬停时显示 tooltip
class UiIconButton extends StatelessWidget {
  const UiIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.outlined = false,
    this.size = 40,
    this.iconSize = 20,
    this.color = AppUi.text,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool outlined;
  final double size;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: iconSize),
      color: color,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        backgroundColor: outlined ? AppUi.surface : Colors.transparent,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(outlined ? 10 : size / 2),
          side: outlined ? const BorderSide(color: AppUi.borderStrong) : BorderSide.none,
        ),
      ),
    );
  }
}

/// 在线状态的小圆点
class UiStatusDot extends StatelessWidget {
  const UiStatusDot({super.key, required this.online, this.size = 7});

  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: online ? AppUi.online : AppUi.offline,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 设备图标，颜色按设备类型区分，离线时变灰
class UiDeviceAvatar extends StatelessWidget {
  const UiDeviceAvatar({
    super.key,
    this.type,
    this.size = 34,
    this.dimmed = false,
  });

  final DeviceType? type;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final Color color = dimmed ? AppUi.textSecondary : (type ?? DeviceType.unknown).deviceColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(uiDeviceIcon(type), size: size * 0.52, color: color),
    );
  }
}

/// 消息气泡：自己发的用主色浅底，别人发的白底
class UiBubble extends StatelessWidget {
  const UiBubble({
    super.key,
    required this.sendByUser,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  final bool sendByUser;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: sendByUser ? AppUi.accentSoft : AppUi.surface,
        border: Border.all(color: sendByUser ? AppUi.accentLine : AppUi.border),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(sendByUser ? 14 : 4),
          topRight: Radius.circular(sendByUser ? 4 : 14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
      ),
      child: child,
    );
  }
}

/// 文件消息里的文件图标底板
class UiFileBadge extends StatelessWidget {
  const UiFileBadge({super.key, required this.child, this.highlighted = false});

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: highlighted ? AppUi.surface : AppUi.subtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: FittedBox(child: child),
    );
  }
}

/// 一行地址加「复制」按钮
class UiCopyField extends StatelessWidget {
  const UiCopyField({
    super.key,
    required this.text,
    this.filledButton = true,
    this.background = AppUi.field,
  });

  final String text;
  final bool filledButton;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: AppUi.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(text, style: AppUi.mono(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          UiButton(
            label: '复制',
            icon: Icons.content_copy_rounded,
            dense: true,
            height: 34,
            variant: filledButton ? UiButtonVariant.filled : UiButtonVariant.outline,
            onPressed: () => uiCopy(text),
          ),
        ],
      ),
    );
  }
}

/// 本机有多块网卡时，选择用哪个地址
class UiAddressSelector extends StatelessWidget {
  const UiAddressSelector({
    super.key,
    required this.addresses,
    required this.selected,
    required this.onChanged,
  });

  final List<LanAddress> addresses;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppUi.segment,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (int i = 0; i < addresses.length; i++)
              Material(
                color: i == selected ? AppUi.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      '${addresses[i].name} · ${addresses[i].ip}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
                        color: i == selected ? AppUi.text : AppUi.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
