import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'theme.dart';

ThemeData light(
  BuildContext context, {
  Color? primary,
}) {
  final $ = context.$;
  final lightThemeData = ThemeData.light(useMaterial3: true);
  // 配色和新界面的设计稿保持一致，老页面用到的 surface、surfaceContainer 等也一起换掉
  ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: AppUi.accent, brightness: Brightness.light).copyWith(
    primary: AppUi.accent,
    onPrimary: Colors.white,
    surface: AppUi.surface,
    onSurface: AppUi.text,
    onSurfaceVariant: AppUi.textSecondary,
    surfaceContainerLowest: AppUi.surface,
    surfaceContainerLow: AppUi.surfaceMuted,
    surfaceContainer: AppUi.subtle,
    surfaceContainerHigh: AppUi.segment,
    surfaceContainerHighest: const Color(0xffe3e5ea),
    outline: AppUi.borderStrong,
    outlineVariant: AppUi.border,
  );
  // Windows 上不指定字体时中文会落到不统一的后备字体上
  final String? fontFamily = GetPlatform.isWindows ? 'Microsoft YaHei UI' : null;
  final TextTheme textTheme = lightThemeData.textTheme.apply(
    fontFamily: fontFamily,
    bodyColor: AppUi.text,
    displayColor: AppUi.text,
  );
  return lightThemeData.copyWith(
    primaryColor: colorScheme.primary,
    scaffoldBackgroundColor: AppUi.background,
    primaryIconTheme: lightThemeData.primaryIconTheme.copyWith(
      color: colorScheme.onSurface,
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
    iconTheme: lightThemeData.iconTheme.copyWith(
      color: colorScheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: colorScheme.surfaceContainer,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: $(12), vertical: $(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular($(8)),
        gapPadding: 0,
        borderSide: const BorderSide(width: 0, color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular($(8)),
        gapPadding: 0,
        borderSide: const BorderSide(width: 0, color: Colors.transparent),
      ),
      filled: true,
    ),
    appBarTheme: lightThemeData.appBarTheme.copyWith(
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      actionsIconTheme: lightThemeData.iconTheme.copyWith(color: colorScheme.primary),
      titleTextStyle: lightThemeData.textTheme.titleLarge!.copyWith(fontSize: $(18), fontWeight: FontWeight.bold),
    ),
    dividerColor: AppUi.border,
    dividerTheme: DividerThemeData(color: AppUi.border, space: $(1)),
    popupMenuTheme: PopupMenuThemeData(color: colorScheme.surface),
    textTheme: textTheme.copyWith(
      bodyMedium: textTheme.bodyMedium!.copyWith(
        fontSize: $(14),
        color: colorScheme.onSurface,
      ),
    ),
    primaryTextTheme: lightThemeData.primaryTextTheme.apply(fontFamily: fontFamily),
    // 原来选中时滑块和轨道都是主色，看不出开关状态
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return const Color(0xffc9cdd4);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        return Colors.transparent;
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return null;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return null;
      }),
    ),
    colorScheme: colorScheme,
  );
}
