import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../models/app_update_result.dart';
import '../services/app_update_checker.dart';

class AppUpdateState {
  final bool isLoading;
  final String? error;
  final AppUpdateResult? result;
  final bool optionalUpdateDismissed;

  AppUpdateState({
    this.isLoading = false,
    this.error,
    this.result,
    this.optionalUpdateDismissed = false,
  });

  AppUpdateState copyWith({
    bool? isLoading,
    String? error,
    AppUpdateResult? result,
    bool? optionalUpdateDismissed,
  }) {
    return AppUpdateState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      result: result ?? this.result,
      optionalUpdateDismissed:
          optionalUpdateDismissed ?? this.optionalUpdateDismissed,
    );
  }
}

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  final AppUpdateChecker _checker;

  AppUpdateNotifier(this._checker) : super(AppUpdateState());

  /// Checks for updates.
  /// Note: Absolutely NO BuildContext, dialog popups, or routing logic happens here.
  Future<AppUpdateResult?> checkForUpdates() async {
    if (state.isLoading) return state.result;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _checker.checkUpdate();
      state = state.copyWith(isLoading: false, result: result);
      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error occurred in AppUpdateNotifier while checking updates',
        e,
        stackTrace,
      );
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Sets the session-level flag indicating the user has dismissed an optional update.
  void dismissOptionalUpdate() {
    AppLogger.info('Optional update dismissed by user.');
    state = state.copyWith(optionalUpdateDismissed: true);
  }
}

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
      final checker = ref.watch(appUpdateCheckerProvider);
      return AppUpdateNotifier(checker);
    });
