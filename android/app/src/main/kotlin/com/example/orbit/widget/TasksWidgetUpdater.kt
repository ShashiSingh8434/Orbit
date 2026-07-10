package com.example.orbit.widget

import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

data class TaskItem(
    val id: String,
    val title: String,
    val status: String,
    val completedAt: String?
) {
    val isCompleted: Boolean
        get() = status == "completed"
}

object TasksWidgetUpdater {
    fun getTasks(context: Context): List<TaskItem> {
        val prefs = HomeWidgetPlugin.getData(context)
        val tasks = mutableListOf<TaskItem>()
        val tasksJsonStr = prefs.getString("tasks_data", "[]")

        try {
            val jsonArray = JSONArray(tasksJsonStr ?: "[]")
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                tasks.add(TaskItem(
                    id = obj.optString("id", ""),
                    title = obj.optString("title", ""),
                    status = obj.optString("status", "pending"),
                    completedAt = if (obj.isNull("completedAt")) null else obj.optString("completedAt", null)
                ))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return tasks
    }
}
