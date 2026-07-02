class VersionCompare {
  VersionCompare._();

  /// Compares the installed build number with the remote latest version code.
  /// Returns true if the installed build number is strictly less than the latest version code.
  static bool isUpdateRequired({
    required int installedBuildNumber,
    required int latestVersionCode,
  }) {
    return installedBuildNumber < latestVersionCode;
  }
}
