package com.example.orbit.widget

import android.content.Context
import android.util.Log
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

class ToggleTaskStatusAction : ActionCallback {
    companion object {
        val taskIdKey = ActionParameters.Key<String>("task_id")
        val isCompletedKey = ActionParameters.Key<Boolean>("is_completed")
    }

    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val taskId = parameters[taskIdKey]
        val isCompleted = parameters[isCompletedKey]
        Log.d("TasksWidgetAction", "onAction clicked. taskId: $taskId, isCompleted: $isCompleted")
        if (taskId == null || isCompleted == null) {
            Log.e("TasksWidgetAction", "Error: parameters are null!")
            return
        }

        val prefs = HomeWidgetPlugin.getData(context)
        
        // 1. Update the local tasks_data list immediately so UI changes without waiting for Flutter
        val tasksJsonStr = prefs.getString("tasks_data", "[]")
        Log.d("TasksWidgetAction", "Current SharedPreferences tasks_data: $tasksJsonStr")
        try {
            val jsonArray = JSONArray(tasksJsonStr ?: "[]")
            var updated = false
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
                    updated = true
                    break
                }
            }
            val committed = prefs.edit().putString("tasks_data", jsonArray.toString()).commit()
            Log.d("TasksWidgetAction", "Updated local tasks_data JSON: ${jsonArray.toString()}, committed: $committed, found/updated: $updated")
        } catch (e: Exception) {
            Log.e("TasksWidgetAction", "Error updating local tasks_data JSON", e)
        }

        // 2. Queue the toggle for Flutter database sync
        val pendingTogglesStr = prefs.getString("pending_task_toggles", "{}")
        try {
            val pendingObj = JSONObject(pendingTogglesStr ?: "{}")
            pendingObj.put(taskId, isCompleted)
            val committed = prefs.edit().putString("pending_task_toggles", pendingObj.toString()).commit()
            Log.d("TasksWidgetAction", "Updated pending_task_toggles: ${pendingObj.toString()}, committed: $committed")
        } catch (e: Exception) {
            Log.e("TasksWidgetAction", "Error updating pending_task_toggles", e)
        }

        // 3. Force Jetpack Glance to recompose immediately by updating its preferences state (NonCancellable context)
        withContext(NonCancellable) {
            try {
                updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { glancePrefs ->
                    val toggleTriggerKey = stringPreferencesKey("toggle_trigger")
                    glancePrefs.toMutablePreferences().apply {
                        this[toggleTriggerKey] = java.util.UUID.randomUUID().toString()
                    }
                }
                Log.d("TasksWidgetAction", "Forced Glance state recompose trigger")
            } catch (e: Exception) {
                Log.e("TasksWidgetAction", "Error updating Glance preferences state", e)
            }

            // 4. Redraw TasksWidget UI
            try {
                TasksWidget().update(context, glanceId)
                Log.d("TasksWidgetAction", "Called TasksWidget.update")
            } catch (e: Exception) {
                Log.e("TasksWidgetAction", "Error updating TasksWidget", e)
            }
        }

        // 5. Send background broadcast to boot Flutter background isolate and sync immediately
        try {
            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("homeWidget://toggleTask?taskId=$taskId&isCompleted=$isCompleted")
            )
            backgroundIntent.send()
            Log.d("TasksWidgetAction", "Sent background broadcast for Flutter sync isolate")
        } catch (e: Exception) {
            Log.e("TasksWidgetAction", "Error sending background broadcast", e)
        }
    }
}

class ReloadTasksAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        withContext(NonCancellable) {
            // 1. Force Glance recompose
            try {
                updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { glancePrefs ->
                    val toggleTriggerKey = stringPreferencesKey("toggle_trigger")
                    glancePrefs.toMutablePreferences().apply {
                        this[toggleTriggerKey] = java.util.UUID.randomUUID().toString()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            try {
                TasksWidget().update(context, glanceId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 2. Trigger Flutter background task to fetch database tasks and sync SharedPreferences
        try {
            val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("homeWidget://reloadTasks")
            )
            backgroundIntent.send()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
