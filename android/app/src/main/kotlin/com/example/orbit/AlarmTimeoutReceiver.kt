package com.example.orbit

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.ActivityManager

class AlarmTimeoutReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra("alarm_id", -1)
        val classDetails = intent.getStringExtra("class_details") ?: "Upcoming Class"
        
        // If the AlarmService is NOT running, it means the user already stopped the alarm.
        // In that case, we do not show the timeout notification.
        if (!isAlarmServiceRunning(context)) {
            return
        }

        // 1. Stop the alarm service natively
        try {
            val serviceIntent = Intent(context, Class.forName("com.gdelataillade.alarm.alarm.AlarmService"))
            context.stopService(serviceIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        // 2. Show the notification from the app
        showNotification(context, alarmId, classDetails)
    }

    private fun isAlarmServiceRunning(context: Context): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        val services = activityManager.getRunningServices(Int.MAX_VALUE)
        if (services != null) {
            for (info in services) {
                if (info.service.className == "com.gdelataillade.alarm.alarm.AlarmService") {
                    return true
                }
            }
        }
        return false
    }

    private fun showNotification(context: Context, alarmId: Int, classDetails: String) {
        val channelId = "academic_reminder_channel"
        val channelName = "Academic Reminders"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Notifications for upcoming academic classes"
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Open app on notification click
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            alarmId,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Class Reminder")
            .setContentText("Class $classDetails starting soon.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        notificationManager.notify(alarmId + 1000000, builder.build())
    }
}
