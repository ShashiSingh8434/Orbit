package com.example.orbit.widget

import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

object TimetableWidgetUpdater {
    /**
     * Parses the current SharedPreferences payload and returns the list of classes for the specified day.
     */
    fun getClassesForDay(context: Context, day: String): List<ClassSessionItem> {
        val prefs = HomeWidgetPlugin.getData(context)
        val classes = mutableListOf<ClassSessionItem>()
        val timetableJsonStr = prefs.getString("timetable_data", "{}")

        try {
            val json = JSONObject(timetableJsonStr ?: "{}")
            if (json.has(day)) {
                val array = json.getJSONArray(day)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    classes.add(ClassSessionItem(
                        name = obj.optString("name", ""),
                        code = obj.optString("code", ""),
                        slot = obj.optString("slot", ""),
                        room = obj.optString("room", ""),
                        startTime = obj.optString("startTime", ""),
                        endTime = obj.optString("endTime", "")
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return classes
    }
}
