import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/academic_schedule.dart';
import '../widgets/class_card.dart';

/// Service to synchronize the academic schedule data with the native Android widget.
class WidgetSyncService {
  static const String _dataKey = 'timetable_data';
  static const String _widgetName = 'TimetableWidgetReceiver';
  static const String _androidProviderName = 'com.example.orbit.widget.TimetableWidgetReceiver';

  /// Serializes and sends the updated academic schedule to the native widget.
  static Future<void> syncSchedule(AcademicSchedule? schedule) async {
    if (schedule == null) {
      await HomeWidget.saveWidgetData<String>(_dataKey, '{}');
    } else {
      final Map<String, dynamic> jsonPayload = _serializeSchedule(schedule);
      await HomeWidget.saveWidgetData<String>(_dataKey, json.encode(jsonPayload));
    }
    
    // Request widget update from home_widget plugin
    await HomeWidget.updateWidget(
      name: _widgetName,
      androidName: _androidProviderName,
    );
  }

  /// Converts a WeekSchedule structure into a simplified widget-friendly map.
  static Map<String, dynamic> _serializeSchedule(AcademicSchedule schedule) {
    final week = schedule.schedule;
    final Map<String, List<Map<String, dynamic>>> payload = {
      'Monday': _serializeSessions(week.monday),
      'Tuesday': _serializeSessions(week.tuesday),
      'Wednesday': _serializeSessions(week.wednesday),
      'Thursday': _serializeSessions(week.thursday),
      'Friday': _serializeSessions(week.friday),
      'Saturday': _serializeSessions(week.saturday),
      'Sunday': _serializeSessions(week.sunday),
    };
    return payload;
  }

  static List<Map<String, dynamic>> _serializeSessions(List<ClassSession> sessions) {
    return sessions.map((s) {
      return {
        'name': s.name,
        'code': s.code,
        'slot': s.slot,
        'room': s.room,
        // Pre-format timings so Kotlin doesn't duplicate formatting logic
        'startTime': ClassCard.format24to12Hr(s.startTime),
        'endTime': ClassCard.format24to12Hr(s.endTime),
      };
    }).toList();
  }
}
