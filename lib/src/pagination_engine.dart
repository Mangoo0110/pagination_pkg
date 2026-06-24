import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../debouncer.dart';
import 'cache/pagination_mem.dart';
import 'page_fetch_response.dart';

enum PaginationLoadState {
  idle,
  loading,
  refreshing,
  loaded,
  updated,
  allLoaded,
  nopages,
  error,
}

sealed class OnDemandPage<T> {
  final T? cursor;
  final int limit;
  final int pageNo;
  OnDemandPage({required this.limit, required this.pageNo, this.cursor});
}

class LoadNextPage<ItemData> extends OnDemandPage<ItemData> {
  LoadNextPage({required super.limit, required super.pageNo, super.cursor});
}

class LoadPreviousPage<ItemData> extends OnDemandPage<ItemData> {
  LoadPreviousPage({required super.limit, required super.pageNo, super.cursor});
}

class PaginationEngine<ItemUniqueKey, ItemData> extends ChangeNotifier {
  PaginationEngine({
    Map<ItemUniqueKey, ItemData>? items,
    required PaginationMem<ItemUniqueKey, ItemData> mem,
    required this.onDemandPageCall,
    this.perPageLimit = 10,
  }) : _mem = mem {
    if (items != null) _mem.addNextPage(items);
  }

  /// Cache memory
  final PaginationMem<ItemUniqueKey, ItemData> _mem;

  final Future<PageFetchResponse<ItemUniqueKey, ItemData>> Function({
    required OnDemandPage<ItemData> onDemandPage,
  })
  onDemandPageCall;

  final ValueNotifier<PaginationLoadState> _state = ValueNotifier(
    PaginationLoadState.idle,
  );
  final ValueNotifier<String> searchText = ValueNotifier('');

  ValueNotifier<PaginationLoadState> get state => _state;

  /// Default is set to 10 by the constructor.
  /// This is the number of items to be fetched per page. You should maintain this number. If you return more they will be added to the next page
  /// or previous page or skipped depending on the situation.
  final int perPageLimit;
  Debouncer debouncer = Debouncer(milliseconds: 1000);

  DateTime _lastFetchTime = DateTime.now();

  int get totalItemsCount => _mem.length;

  ItemData? itemAt(int index) => _mem.itemAt(index);

  int get length => _mem.length;

  bool get isEmplty => _mem.isEmpty;

  void deleteItemAt(int index) => _mem.deleteItemAt(index);

  void updateItemAt(int index, ItemData item) => _mem.updateItemAt(index, item);

  Future<PaginationPage<ItemUniqueKey, ItemData>?> requestData({
    required OnDemandPage<ItemData> onDemandPage,
  }) async {
    PaginationPage<ItemUniqueKey, ItemData>? page;
    // await debouncer.run(() async {

    // });
    final res = await onDemandPageCall(onDemandPage: onDemandPage);
    if (res is PaginationError) {
      debugPrint(
        "Error fetching page: ${res.page} with message: ${(res as PaginationError).message}",
      );
      setError(error: res as PaginationError);
    } else if (res is PaginationPage<ItemUniqueKey, ItemData>) {
      debugPrint("Fetched page: ${res.page} with items: ${res.items}");
      page = res;
    }
    _lastFetchTime = DateTime.now();
    return page;
  }

  void search(String text) async {
    debouncer.run(() async {
      if (state.value == PaginationLoadState.refreshing) {
        return;
      }
      searchText.value = text;
      setRefresh();

      final page = await requestData(
        onDemandPage: LoadNextPage<ItemData>(
          limit: perPageLimit,
          pageNo: 1,
          cursor: null,
        ),
      );
      debugPrint(
        "Search result for text: $text is page: ${page?.page} with items count: ${page?.items.length}",
      );
      if (page != null) {
        debugPrint("Adding items: ${page.items.length}");
        _mem.addNextPage(page.items);
        state.value = PaginationLoadState.loaded;
      } else if (state.value == PaginationLoadState.error) {
        notifyListeners();
        return;
      } else {
        debugPrint("No items to add.. setting state to nopages");
        state.value = PaginationLoadState.nopages;
      }
      notifyListeners();
    });
  }

  /// Sets the state to [PaginationLoadState.refreshing]
  /// Clears the [PaginationMem]
  ///
  /// Triggers [notifyListeners], as memory along with state has changed
  void setRefresh() {
    _mem.clear();
    state.value = PaginationLoadState.refreshing;
    notifyListeners();
  }

  /// Sets the state to [PaginationLoadState.loading]
  /// #### NOTE: This does not trigger [notifyListeners]
  setError({PaginationError? error}) {
    state.value = PaginationLoadState.error;
    notifyListeners();
  }

  /// Sets the state to [PaginationLoadState.loading]
  /// #### NOTE: This does not trigger [notifyListeners]
  void setLoading() {
    state.value = PaginationLoadState.loading;
  }

  /// Triggers [notifyListeners]
  void setNoPages() {
    state.value = PaginationLoadState.nopages;
    notifyListeners();
  }

  /// Checks if current state is [PaginationLoadState.allLoaded] or [PaginationLoadState.nopages] and last fetch time is less than 3.5 minutes
  bool _shouldTryLoadMore() {
    if ((state.value == PaginationLoadState.allLoaded ||
            state.value == PaginationLoadState.nopages) &&
        _lastFetchTime.difference(DateTime.now()).inMilliseconds.abs() <
            (1000 * 60 * 3.5)) {
      debugPrint(
        "Should not try to load more.. ${_lastFetchTime.difference(DateTime.now()).inMilliseconds.abs()}ms and state: ${state.value}",
      );
      return false;
    }
    return true;
  }

  Future<void> loadNextPage() async {
    if (!_shouldTryLoadMore()) {
      return;
    }

    await debouncer.run(() async {
      state.value = PaginationLoadState.loading;
      final res = await requestData(
        onDemandPage: LoadNextPage(
          limit: perPageLimit,
          pageNo: _mem.nextPageToFetch,
          cursor: _mem.last,
        ),
      );

      if (res == null) {
        notifyListeners();
        return;
      }
      _mem.addNextPage(res.items);
      if (res.items.isEmpty) {
        state.value = PaginationLoadState.allLoaded;
      } else {
        state.value = PaginationLoadState.loaded;
      }
      notifyListeners();
    });
  }

  Future<void> loadPreviousPage() async {
    if (!_shouldTryLoadMore() ||
        (_mem.previousPageToFetch < _mem.firstPageVal)) {
      return;
    }

    debouncer.run(() async {
      debugPrint("Previous page(${_mem.previousPageToFetch}) in demand...");
      final res = await requestData(
        onDemandPage: LoadPreviousPage(
          limit: perPageLimit,
          pageNo: _mem.previousPageToFetch,
          cursor: _mem.first,
        ),
      );
      if (res == null) {
        notifyListeners();
        return;
      }
      _mem.addFrontPage(res.items);
      if (res.items.isEmpty) {
        state.value = PaginationLoadState.allLoaded;
      } else {
        state.value = PaginationLoadState.loaded;
      }
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    debugPrint("Refreshing...");
    search(searchText.value);
  }

  void upsertItem({
    required ItemUniqueKey key,
    required ItemData item,
  }) {
    //state.value = PaginationLoadState.loading;
    _mem.upsertItem(key: key, item: item);
    state.value = PaginationLoadState.updated;
  }

  @override
  void dispose() {
    super.dispose();
    _mem.clear();
    _state.dispose();
    searchText.dispose();
  }
}
