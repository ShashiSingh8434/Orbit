import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_service.dart';
import 'voice_controller.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});

final voiceControllerProvider =
    StateNotifierProvider<VoiceController, VoiceState>((ref) {
      final service = ref.watch(voiceServiceProvider);
      return VoiceController(service);
    });
