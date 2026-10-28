/// 包级配置。
class Config {
  Config._();

  /// 本包的名称，宿主加载本包里的资源时使用，例如
  /// `SvgPicture.asset('assets/icon/dir.svg', package: Config.package)`。
  static const String package = 'file_manager';
}
