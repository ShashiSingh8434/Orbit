import 'package:cloud_firestore/cloud_firestore.dart';

class PaginatedResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}
