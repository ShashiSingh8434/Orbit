import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_service.dart';
import 'voice_controller.dart';

/// A single [VoiceService] instance shared across the entire app.
///
/// Using a single instance ensures:
/// - Only one STT initialisation / permission request.
/// - No resource leaks from multiple abandoned instances.
/// - Consistent state when voice is used on multiple screens.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});

/// The app-wide [VoiceController].
///
/// All [VoiceInputButton] widgets read from this provider. Because it is a
/// [StateNotifierProvider], Riverpod caches it for the app's lifetime and
/// rebuilds dependants only when [VoiceState] changes.
final voiceControllerProvider =
    StateNotifierProvider<VoiceController, VoiceState>((ref) {
      final service = ref.watch(voiceServiceProvider);
      return VoiceController(service);
    });
