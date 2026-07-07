package com.example.orbit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.orbit.widget.WidgetPinManager

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private val PIN_CHANNEL = "com.example.orbit/widget_pin"
    private val ALARM_HELPER_CHANNEL = "com.example.orbit/alarm_helper"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        try {
            com.gdelataillade.alarm.services.AlarmRingingLiveData.instance.removeObservers(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWidgetPinningSupported" -> {
                    val supported = WidgetPinManager.isPinningSupported(applicationContext)
                    result.success(supported)
                }
                "requestWidgetPin" -> {
                    val success = WidgetPinManager.requestPin(applicationContext)
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_HELPER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarmTimeout" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: -1
                    val timeoutTimestamp = call.argument<Long>("timeoutTimestamp") ?: 0L
                    val classDetails = call.argument<String>("classDetails") ?: ""
                    setAlarmTimeout(alarmId, timeoutTimestamp, classDetails)
                    result.success(null)
                }
                "cancelAlarmTimeout" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: -1
                    cancelAlarmTimeout(alarmId)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setAlarmTimeout(alarmId: Int, timeoutTimestamp: Long, classDetails: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(applicationContext, AlarmTimeoutReceiver::class.java).apply {
            putExtra("alarm_id", alarmId)
            putExtra("class_details", classDetails)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                timeoutTimestamp,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                timeoutTimestamp,
                pendingIntent
            )
        }
    }

    private fun cancelAlarmTimeout(alarmId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(applicationContext, AlarmTimeoutReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            alarmId,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }
}
