package com.example.orbit.widget

import android.content.Context
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

/**
 * Helper to update selected day in Glance DataStore preferences.
 */
private suspend fun navigateWidgetDay(context: Context, glanceId: GlanceId, direction: Int) {
    val weekdays = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    
    withContext(NonCancellable) {
        updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
            val selectedDayKey = stringPreferencesKey("widget_selected_day")
            val lastSelectedDateKey = stringPreferencesKey("widget_last_selected_date")

            val calendar = java.util.Calendar.getInstance()
            val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
            val todayWeekday = when (dayOfWeek) {
                java.util.Calendar.MONDAY -> "Monday"
                java.util.Calendar.TUESDAY -> "Tuesday"
                java.util.Calendar.WEDNESDAY -> "Wednesday"
                java.util.Calendar.THURSDAY -> "Thursday"
                java.util.Calendar.FRIDAY -> "Friday"
                java.util.Calendar.SATURDAY -> "Saturday"
                java.util.Calendar.SUNDAY -> "Sunday"
                else -> "Monday"
            }

            val todayDateString = java.text.SimpleDateFormat("yyyy-MM-d", java.util.Locale.US).format(java.util.Date())
            val lastSelectedDate = prefs[lastSelectedDateKey] ?: ""
            val currentDay = if (lastSelectedDate == todayDateString) {
                prefs[selectedDayKey] ?: todayWeekday
            } else {
                todayWeekday
            }

            val currentIndex = weekdays.indexOf(currentDay)
            val targetIndex = if (currentIndex != -1) {
                (currentIndex + direction + weekdays.size) % weekdays.size
            } else {
                0
            }
            val newDay = weekdays[targetIndex]

            prefs.toMutablePreferences().apply {
                this[selectedDayKey] = newDay
                this[lastSelectedDateKey] = todayDateString
            }
        }
        
        // Request widget layout redraw
        TimetableWidget().update(context, glanceId)
    }
}

/**
 * Triggered when clicking the Prev ("←") button. Updates selected day circularly back.
 */
class PrevDayAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        navigateWidgetDay(context, glanceId, -1)
    }
}

/**
 * Triggered when clicking the Next ("→") button. Updates selected day circularly forward.
 */
class NextDayAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        navigateWidgetDay(context, glanceId, 1)
    }
}

/**
 * Triggered when clicking the Reload ("↺") button.
 * Clears any user-selected day override so the widget snaps back to today's schedule
 * and triggers a UI recomposition with the latest cached data.
 */
class ResetDayAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        withContext(NonCancellable) {
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { prefs ->
                val selectedDayKey = stringPreferencesKey("widget_selected_day")
                val lastSelectedDateKey = stringPreferencesKey("widget_last_selected_date")
                // Remove both keys so the widget falls back to today's weekday on next recomposition
                prefs.toMutablePreferences().apply {
                    remove(selectedDayKey)
                    remove(lastSelectedDateKey)
                }
            }
            // Redraw widget — data is already synced from Flutter via SharedPreferences
            TimetableWidget().update(context, glanceId)
        }
    }
}
