import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../models/app_config.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return FirebaseAppConfigRepository();
});

abstract class AppConfigRepository {
  Future<AppConfig?> fetchAppConfig();
}

class FirebaseAppConfigRepository implements AppConfigRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<AppConfig?> fetchAppConfig() async {
    try {
      AppLogger.info('Fetching remote app configuration from Firestore...');
      final doc = await _firestore.collection('app_config').doc('current').get();

      if (!doc.exists) {
        AppLogger.warning('AppConfig document does not exist in Firestore (app_config/current)');
        return null;
      }

      final config = AppConfig.fromFirestore(doc);
      AppLogger.info('Successfully fetched remote app configuration: $config');
      return config;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to fetch remote app configuration from Firestore', e, stackTrace);
      return null;
    }
  }
}
