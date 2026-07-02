import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/utils/app_logger.dart';
import '../data/app_config_repository.dart';
import '../models/app_update_result.dart';
import '../utils/version_compare.dart';

final appUpdateCheckerProvider = Provider<AppUpdateChecker>((ref) {
  final repository = ref.watch(appConfigRepositoryProvider);
  return AppUpdateChecker(repository);
});

class AppUpdateChecker {
  final AppConfigRepository _repository;

  AppUpdateChecker(this._repository);

  Future<AppUpdateResult> checkUpdate() async {
    AppLogger.info('Starting app update check...');

    // 1. Get installed package details
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersionName = packageInfo.version;
    final installedBuildString = packageInfo.buildNumber;
    final installedBuildNumber = int.tryParse(installedBuildString) ?? 0;

    AppLogger.info(
      'Installed Version: $installedVersionName, Installed Build Number: $installedBuildNumber',
    );

    // 2. Fetch remote configurations
    final config = await _repository.fetchAppConfig();
    if (config == null) {
      AppLogger.warning('Remote AppConfig could not be retrieved. Skipping update check.');
      return AppUpdateResult(
        updateRequired: false,
        forceUpdate: false,
        installedVersionName: installedVersionName,
        installedVersionCode: installedBuildNumber,
      );
    }

    // 3. Compare build numbers
    final updateRequired = VersionCompare.isUpdateRequired(
      installedBuildNumber: installedBuildNumber,
      latestVersionCode: config.latestVersionCode,
    );

    AppLogger.info(
      'Update comparison: installedCode=$installedBuildNumber, latestCode=${config.latestVersionCode}. '
      'Update Required: $updateRequired, Force Update: ${config.forceUpdate}',
    );

    return AppUpdateResult(
      updateRequired: updateRequired,
      forceUpdate: config.forceUpdate,
      config: config,
      installedVersionName: installedVersionName,
      installedVersionCode: installedBuildNumber,
    );
  }
}
