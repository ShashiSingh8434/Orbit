import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/paginated_result.dart';

class PaginatedState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isLoadMore;
  final bool hasMore;
  final String? error;

  PaginatedState({
    required this.items,
    required this.isLoading,
    required this.isLoadMore,
    required this.hasMore,
    this.error,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadMore,
    bool? hasMore,
    String? error,
  }) {
    return PaginatedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadMore: isLoadMore ?? this.isLoadMore,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

class PaginatedListNotifier<T> extends StateNotifier<PaginatedState<T>> {
  final Future<PaginatedResult<T>> Function(Object? startAfter)
  fetchPage;
  Object? _lastDoc;

  PaginatedListNotifier({required this.fetchPage})
    : super(
        PaginatedState(
          items: [],
          isLoading: true,
          isLoadMore: false,
          hasMore: true,
        ),
      ) {
    loadNextPage();
  }

  Future<void> refresh() async {
    _lastDoc = null;
    state = PaginatedState(
      items: [],
      isLoading: true,
      isLoadMore: false,
      hasMore: true,
    );
    await loadNextPage();
  }

  Future<void> loadNextPage() async {
    if (!state.hasMore || state.isLoadMore) return;

    final isFirstLoad = state.items.isEmpty;
    if (isFirstLoad) {
      state = state.copyWith(isLoading: true);
    } else {
      state = state.copyWith(isLoadMore: true);
    }

    try {
      final res = await fetchPage(_lastDoc);
      _lastDoc = res.lastDoc;
      state = state.copyWith(
        items: [...state.items, ...res.items],
        isLoading: false,
        isLoadMore: false,
        hasMore: res.hasMore,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadMore: false,
        error: e.toString(),
      );
    }
  }

  void updateItem(T Function(T) mapper) {
    state = state.copyWith(items: state.items.map(mapper).toList());
  }

  void removeItem(bool Function(T) test) {
    state = state.copyWith(
      items: state.items.where((item) => !test(item)).toList(),
    );
  }

  void addItem(T item) {
    state = state.copyWith(items: [item, ...state.items]);
  }
}
