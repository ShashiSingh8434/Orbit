package com.example.orbit.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build

object WidgetPinManager {
    /**
     * Checks if requesting pinning is supported by the user's launcher/device (API level 26+).
     */
    fun isPinningSupported(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                appWidgetManager.isRequestPinAppWidgetSupported
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
    }

    /**
     * Attempts to request native home screen widget pinning.
     * Returns true if request was sent successfully, false otherwise.
     */
    fun requestPin(context: Context, widgetType: String = "timetable"): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val receiverClass = if (widgetType == "tasks") {
                    TasksWidgetReceiver::class.java
                } else {
                    TimetableWidgetReceiver::class.java
                }
                val provider = ComponentName(context, receiverClass)
                
                if (appWidgetManager.isRequestPinAppWidgetSupported) {
                    appWidgetManager.requestPinAppWidget(provider, null, null)
                } else {
                    false
                }
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
    }
}
