import 'package:flutter/services.dart';

/// Service to handle native Android Home Screen Widget Pinning requests.
class HomeWidgetPinService {
  static const MethodChannel _channel = MethodChannel('com.example.orbit/widget_pin');

  /// Checks if requesting pinning is supported by the user's launcher/device (API level 26+).
  static Future<bool> isWidgetPinningSupported() async {
    try {
      final bool? isSupported = await _channel.invokeMethod<bool>('isWidgetPinningSupported');
      return isSupported ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the native home screen widget pinning dialog.
  /// Returns true if the dialog request was initiated successfully, false otherwise.
  static Future<bool> requestWidgetPin() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('requestWidgetPin');
      return success ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
