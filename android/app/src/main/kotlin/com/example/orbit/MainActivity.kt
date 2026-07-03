package com.example.orbit

import io.flutter.embedding.android.FlutterActivity

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.orbit.widget.WidgetPinManager

class MainActivity : FlutterActivity() {
    private val PIN_CHANNEL = "com.example.orbit/widget_pin"

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
    }
}
