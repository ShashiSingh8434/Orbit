package com.example.orbit.widget

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class ToggleTaskStatusAction : ActionCallback {
    companion object {
        val taskIdKey = ActionParameters.Key<String>("task_id")
        val isCompletedKey = ActionParameters.Key<Boolean>("is_completed")
    }

    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val taskId = parameters[taskIdKey] ?: return
        val isCompleted = parameters[isCompletedKey] ?: return

        val prefs = HomeWidgetPlugin.getData(context)
        
        // 1. Update the local tasks_data list immediately so UI changes without waiting for Flutter
        val tasksJsonStr = prefs.getString("tasks_data", "[]")
        try {
            val jsonArray = JSONArray(tasksJsonStr ?: "[]")
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                if (obj.optString("id") == taskId) {
                    obj.put("status", if (isCompleted) "completed" else "pending")
                    if (isCompleted) {
                        val todayIso = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).format(java.util.Date())
                        obj.put("completedAt", todayIso)
                    } else {
                        obj.remove("completedAt")
                    }
                    break
                }
            }
            prefs.edit().putString("tasks_data", jsonArray.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Queue the toggle for Flutter database sync
        val pendingTogglesStr = prefs.getString("pending_task_toggles", "{}")
        try {
            val pendingObj = JSONObject(pendingTogglesStr ?: "{}")
            pendingObj.put(taskId, isCompleted)
            prefs.edit().putString("pending_task_toggles", pendingObj.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 3. Redraw TasksWidget UI
        TasksWidget().update(context, glanceId)
    }
}
