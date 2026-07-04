import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiNotification {
  final String message;
  final DateTime timestamp;

  AiNotification(this.message) : timestamp = DateTime.now();
}

class AiNotificationNotifier extends StateNotifier<AiNotification?> {
  AiNotificationNotifier() : super(null);

  void notify(String message) {
    state = AiNotification(message);
  }
}

final aiNotificationProvider =
    StateNotifierProvider<AiNotificationNotifier, AiNotification?>((ref) {
      return AiNotificationNotifier();
    });
