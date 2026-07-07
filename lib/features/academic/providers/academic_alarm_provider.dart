import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/academic_schedule.dart';
import 'academic_provider.dart';
import '../services/alarm_helper.dart';
import '../../../core/providers/shared_preferences_provider.dart';

/// Model for academic reminder settings.
class AcademicReminderSettings {
  final int minutesBefore;
  final String ringtoneType;
  final String ringtonePath;
  final String ringtoneName;
  final bool isConfigured;

  AcademicReminderSettings({
    required this.minutesBefore,
    required this.ringtoneType,
    required this.ringtonePath,
    required this.ringtoneName,
    required this.isConfigured,
  });
}

/// Notifier that manages saving and updating reminder settings reactively.
class AcademicReminderSettingsNotifier extends StateNotifier<AcademicReminderSettings> {
  final SharedPreferences _prefs;

  AcademicReminderSettingsNotifier(this._prefs)
      : super(AcademicReminderSettings(
          minutesBefore: _prefs.getInt('academic_reminder_minutes') ?? 15,
          ringtoneType: _prefs.getString('academic_reminder_ringtone_type') ?? 'asset',
          ringtonePath: _prefs.getString('academic_reminder_ringtone_path') ?? 'assets/freedom.mp3',
          ringtoneName: _prefs.getString('academic_reminder_ringtone_name') ?? 'Freedom',
          isConfigured: _prefs.getBool('academic_reminder_settings_configured') ?? false,
        ));

  Future<void> updateSettings({
    required int minutesBefore,
    required String ringtoneType,
    required String ringtonePath,
    required String ringtoneName,
  }) async {
    await _prefs.setInt('academic_reminder_minutes', minutesBefore);
    await _prefs.setString('academic_reminder_ringtone_type', ringtoneType);
    await _prefs.setString('academic_reminder_ringtone_path', ringtonePath);
    await _prefs.setString('academic_reminder_ringtone_name', ringtoneName);
    await _prefs.setBool('academic_reminder_settings_configured', true);

    state = AcademicReminderSettings(
      minutesBefore: minutesBefore,
      ringtoneType: ringtoneType,
      ringtonePath: ringtonePath,
      ringtoneName: ringtoneName,
      isConfigured: true,
    );
  }
}

/// Provider for academic reminder settings state.
final academicReminderSettingsProvider =
    StateNotifierProvider<AcademicReminderSettingsNotifier, AcademicReminderSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AcademicReminderSettingsNotifier(prefs);
});

/// Provider tracking active reminder alarm session keys.
final academicAlarmProvider = StateNotifierProvider<AcademicAlarmNotifier, Set<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final notifier = AcademicAlarmNotifier(prefs);

  ref.listen(academicStateProvider, (previous, next) {
    final schedule = next.schedule;
    if (schedule != null) {
      notifier.reschedulePassedAlarms(schedule.schedule);
    }
  }, fireImmediately: true);

  return notifier;
});

class AcademicAlarmNotifier extends StateNotifier<Set<String>> {
  final SharedPreferences _prefs;

  AcademicAlarmNotifier(this._prefs) : super({}) {
    _loadActiveAlarms();
  }

  void _loadActiveAlarms() {
    final list = _prefs.getStringList('academic_active_alarm_keys') ?? [];
    state = list.toSet();
  }

  bool isReminderSet(String day, ClassSession session) {
    final key = _getSessionKey(day, session);
    return state.contains(key);
  }

  String _getSessionKey(String day, ClassSession session) {
    return '${day}_${session.startTime}_${session.code}';
  }

  int _getAlarmId(String key) {
    return key.hashCode & 0x7FFFFFFF;
  }

  Future<void> toggleReminder(String day, ClassSession session, BuildContext context) async {
    final key = _getSessionKey(day, session);
    final id = _getAlarmId(key);
    final isSet = state.contains(key);

    if (isSet) {
      // Cancel reminder
      await Alarm.stop(id);
      await AlarmHelper.cancelAlarmTimeout(id);

      final newKeys = Set<String>.from(state)..remove(key);
      await _prefs.setStringList('academic_active_alarm_keys', newKeys.toList());
      state = newKeys;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder removed.')),
        );
      }
    } else {
      // Request notifications permission on Android (Exact alarm permission is automatically
      // granted via USE_EXACT_ALARM in manifest, so it doesn't need to be checked at runtime).
      if (Platform.isAndroid) {
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          final request = await Permission.notification.request();
          if (!request.isGranted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification permission is required to set class reminders.')),
              );
            }
            return;
          }
        }
      }

      // Read settings
      final minutesBefore = _prefs.getInt('academic_reminder_minutes') ?? 15;
      final ringtonePath = _prefs.getString('academic_reminder_ringtone_path') ?? 'assets/freedom.mp3';

      final alarmTime = _calculateNextAlarmDateTime(day, session.startTime, minutesBefore);

      final alarmSettings = AlarmSettings(
        id: id,
        dateTime: alarmTime,
        assetAudioPath: ringtonePath,
        loopAudio: true,
        vibrate: true,
        volume: 0.8,
        fadeDuration: 5.0,
        androidFullScreenIntent: true,
        notificationSettings: NotificationSettings(
          title: 'Class Reminder',
          body: '${session.code}: ${session.name} starts at ${session.startTime}',
          stopButton: 'Stop',
        ),
      );

      final setSuccess = await Alarm.set(alarmSettings: alarmSettings);
      if (setSuccess) {
        // Schedule native timeout at alarmTime + 2 minutes
        final timeoutTimestamp = alarmTime.millisecondsSinceEpoch + 2 * 60 * 1000;
        await AlarmHelper.setAlarmTimeout(
          id,
          timeoutTimestamp,
          '${session.code} at ${session.startTime}',
        );

        final newKeys = Set<String>.from(state)..add(key);
        await _prefs.setStringList('academic_active_alarm_keys', newKeys.toList());
        state = newKeys;

        final formattedTime = _formatDateTime(alarmTime);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reminder set for $formattedTime')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set reminder.')),
          );
        }
      }
    }
  }

  DateTime _calculateNextAlarmDateTime(String dayName, String startTimeStr, int minutesBefore) {
    final now = DateTime.now();
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final targetWeekday = weekdays.indexOf(dayName) + 1;

    final timeParts = startTimeStr.split(':');
    final hours = int.parse(timeParts[0]);
    final minutes = int.parse(timeParts[1]);

    var targetDate = DateTime(now.year, now.month, now.day, hours, minutes);

    var daysToAdd = targetWeekday - now.weekday;
    if (daysToAdd < 0) {
      daysToAdd += 7;
    }

    targetDate = targetDate.add(Duration(days: daysToAdd));

    var alarmDate = targetDate.subtract(Duration(minutes: minutesBefore));

    if (alarmDate.isBefore(now)) {
      alarmDate = alarmDate.add(const Duration(days: 7));
    }

    return alarmDate;
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:$min $period';
  }

  /// Clears all currently set alarms reactively.
  Future<void> clearAllReminders() async {
    for (final key in state) {
      final id = _getAlarmId(key);
      await Alarm.stop(id);
      await AlarmHelper.cancelAlarmTimeout(id);
    }
    await _prefs.setStringList('academic_active_alarm_keys', []);
    state = {};
  }

  /// Automatically checks and reschedules passed or misaligned alarms for next week.
  Future<void> reschedulePassedAlarms(WeekSchedule schedule) async {
    final now = DateTime.now();
    final minutesBefore = _prefs.getInt('academic_reminder_minutes') ?? 15;
    final ringtonePath = _prefs.getString('academic_reminder_ringtone_path') ?? 'assets/freedom.mp3';

    final currentKeys = Set<String>.from(state);

    for (final key in currentKeys) {
      final parts = key.split('_');
      if (parts.length < 3) continue;
      final day = parts[0];
      final startTime = parts[1];
      final code = parts[2];

      final sessions = _getSessionsForDay(schedule, day);
      final session = sessions.firstWhere(
        (s) => s.startTime == startTime && s.code == code,
        orElse: () => ClassSession(
          code: code,
          name: 'Class',
          startTime: startTime,
          endTime: '',
          faculty: '',
          room: '',
        ),
      );

      final id = _getAlarmId(key);
      final alarm = await Alarm.getAlarm(id);
      final calculatedAlarmTime = _calculateNextAlarmDateTime(day, session.startTime, minutesBefore);

      if (alarm == null ||
          alarm.dateTime.isBefore(now) ||
          alarm.dateTime != calculatedAlarmTime ||
          alarm.assetAudioPath != ringtonePath) {
        final alarmSettings = AlarmSettings(
          id: id,
          dateTime: calculatedAlarmTime,
          assetAudioPath: ringtonePath,
          loopAudio: true,
          vibrate: true,
          volume: 0.8,
          fadeDuration: 5.0,
          androidFullScreenIntent: true,
          notificationSettings: NotificationSettings(
            title: 'Class Reminder',
            body: 'Class ${session.code}: ${session.name} starts soon at ${session.startTime}!',
            stopButton: 'Stop',
          ),
        );
        await Alarm.set(alarmSettings: alarmSettings);
        
        final timeoutTimestamp = calculatedAlarmTime.millisecondsSinceEpoch + 2 * 60 * 1000;
        await AlarmHelper.setAlarmTimeout(
          id,
          timeoutTimestamp,
          '${session.code} at ${session.startTime}',
        );
      }
    }
  }

  List<ClassSession> _getSessionsForDay(WeekSchedule schedule, String day) {
    switch (day) {
      case 'Monday': return schedule.monday;
      case 'Tuesday': return schedule.tuesday;
      case 'Wednesday': return schedule.wednesday;
      case 'Thursday': return schedule.thursday;
      case 'Friday': return schedule.friday;
      case 'Saturday': return schedule.saturday;
      case 'Sunday': return schedule.sunday;
      default: return [];
    }
  }
}
