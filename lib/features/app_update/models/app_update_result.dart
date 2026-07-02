import 'app_config.dart';

class AppUpdateResult {
  final bool updateRequired;
  final bool forceUpdate;
  final AppConfig? config;
  final String installedVersionName;
  final int installedVersionCode;

  AppUpdateResult({
    required this.updateRequired,
    required this.forceUpdate,
    this.config,
    required this.installedVersionName,
    required this.installedVersionCode,
  });

  @override
  String toString() {
    return 'AppUpdateResult(updateRequired: $updateRequired, forceUpdate: $forceUpdate, config: $config, installedVersionName: $installedVersionName, installedVersionCode: $installedVersionCode)';
  }
}
