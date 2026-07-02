import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfig {
  final int latestVersionCode;
  final String latestVersionName;
  final String downloadUrl;
  final bool forceUpdate;
  final String releaseNotes;
  final DateTime updatedAt;

  AppConfig({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.updatedAt,
  });

  factory AppConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppConfig(
      latestVersionCode: data['latestVersionCode'] as int? ?? 0,
      latestVersionName: data['latestVersionName'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      forceUpdate: data['forceUpdate'] as bool? ?? false,
      releaseNotes: data['releaseNotes'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'latestVersionCode': latestVersionCode,
      'latestVersionName': latestVersionName,
      'downloadUrl': downloadUrl,
      'forceUpdate': forceUpdate,
      'releaseNotes': releaseNotes,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppConfig copyWith({
    int? latestVersionCode,
    String? latestVersionName,
    String? downloadUrl,
    bool? forceUpdate,
    String? releaseNotes,
    DateTime? updatedAt,
  }) {
    return AppConfig(
      latestVersionCode: latestVersionCode ?? this.latestVersionCode,
      latestVersionName: latestVersionName ?? this.latestVersionName,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AppConfig(latestVersionCode: $latestVersionCode, latestVersionName: $latestVersionName, downloadUrl: $downloadUrl, forceUpdate: $forceUpdate, releaseNotes: $releaseNotes, updatedAt: $updatedAt)';
  }
}
