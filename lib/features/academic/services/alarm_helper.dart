import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Helper to communicate with native Android code to schedule alarm timeouts
/// and trigger standard notifications when the app is closed.
class AlarmHelper {
  static const _channel = MethodChannel('com.example.orbit/alarm_helper');

  /// Schedules a native BroadcastReceiver trigger at [timeoutTimestamp] (epoch ms) to stop
  /// the alarm service and show a class reminder notification if it's still ringing.
  static Future<void> setAlarmTimeout(
    int alarmId,
    int timeoutTimestamp,
    String classDetails,
  ) async {
    try {
      await _channel.invokeMethod('setAlarmTimeout', {
        'alarmId': alarmId,
        'timeoutTimestamp': timeoutTimestamp,
        'classDetails': classDetails,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to set alarm timeout: ${e.message}');
    }
  }

  /// Cancels a native timeout alarm broadcast.
  static Future<void> cancelAlarmTimeout(int alarmId) async {
    try {
      await _channel.invokeMethod('cancelAlarmTimeout', {'alarmId': alarmId});
    } on PlatformException catch (e) {
      debugPrint('Failed to cancel alarm timeout: ${e.message}');
    }
  }
}
