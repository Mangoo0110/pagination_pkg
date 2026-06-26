import 'package:flutter/material.dart';
import 'package:pagination_pkg/src/logger.dart';
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
    bool shouldLog = false,
    LoggerColor color = LoggerColor.green,
  }) : _mem = mem,
       _logger = Logger(log: shouldLog, loggerColor: color) {
    if (items != null) _mem.addNextPage(items);
  }

  /// Logger
  final Logger _logger;

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
  /// This is the number of items to be fetched per page. You should maintain this number.
  /// If you return more on the page fetch call, they will be added to the next page
  /// or, previous page or skipped depending on the situation.
  final int perPageLimit;

  int get totalItemsCount => _mem.length;

  ItemData? itemAt(int index) => _mem.itemAt(index);

  int get length => _mem.length;

  bool get isEmpty => _mem.isEmpty;

  @Deprecated('Use isEmpty instead.')
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
    if (res is PaginationError<ItemUniqueKey, ItemData>) {
      _logger.showLog(
        "Error fetching page: ${res.page}, message: ${res.message}",
      );
      setError(error: res);
    } else if (res is PaginationPage<ItemUniqueKey, ItemData>) {
      _logger.showLog(
        "Fetched page: ${res.page}, items-length: ${res.items.length}",
      );
      page = res;
    }
    return page;
  }

  /// Package does not support the debouncing mechanism anymore, its now up to the developer to handle it.
  void search(String text) async {
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
    _logger.showLog(
      "Search result for text: $text is page: ${page?.page} with items count: ${page?.items.length}",
    );

    if (page != null) {
      _logger.showLog("Adding items: ${page.items.length}");
      _mem.addNextPage(page.items);
      state.value = _stateForPage(
        page,
        emptyState: PaginationLoadState.nopages,
      );
    } else if (state.value == PaginationLoadState.error) {
      notifyListeners();
      return;
    } else {
      _logger.showLog("No items to add.. setting state to nopages");
      state.value = PaginationLoadState.nopages;
    }
    notifyListeners();
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
  void setError({PaginationError<ItemUniqueKey, ItemData>? error}) {
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

  /// Checks if current state is [PaginationLoadState.allLoaded] or [PaginationLoadState.nopages].
  bool _shouldTryLoadMore() {
    if (state.value == PaginationLoadState.allLoaded ||
        state.value == PaginationLoadState.nopages) {
      _logger.showLog(
        "Should not try to load more because state is ${state.value}",
      );
      return false;
    }
    return true;
  }

  Future<void> loadNextPage() async {
    // Guard
    if (!_shouldTryLoadMore()) {
      return;
    }

    // Set state to loading
    state.value = PaginationLoadState.loading;
    // Fetch next page
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
    state.value = _stateForPage(res, emptyState: PaginationLoadState.allLoaded);
    notifyListeners();
  }

  Future<void> loadPreviousPage() async {
    // Guard
    if (!_shouldTryLoadMore() ||
        (_mem.previousPageToFetch < _mem.firstPageVal)) {
      return;
    }

    // Set state to loading
    state.value = PaginationLoadState.loading;
    // Fetch previous page
    final res = await requestData(
      // requestData() methods holds the logic for fetching data
      onDemandPage: LoadPreviousPage(
        limit: perPageLimit,
        pageNo: _mem.previousPageToFetch,
        cursor: _mem.first,
      ),
    ); // requestData() methods also handles the error state

    if (res == null) {
      notifyListeners();
      return;
    }
    _mem.addFrontPage(res.items);
    state.value = _stateForPage(res, emptyState: PaginationLoadState.allLoaded);
    notifyListeners();
  }

  Future<void> refresh() async {
    _logger.showLog("Refreshing...");
    search(searchText.value);
  }

  void upsertItem({required ItemUniqueKey key, required ItemData item}) {
    //state.value = PaginationLoadState.loading;
    _mem.upsertItem(key: key, item: item);
    state.value = PaginationLoadState.updated;
    notifyListeners();
  }

  PaginationLoadState _stateForPage(
    PaginationPage<ItemUniqueKey, ItemData> page, {
    required PaginationLoadState emptyState,
  }) {
    if (page.items.isEmpty) return emptyState;
    if (page.hasMore == false) return PaginationLoadState.allLoaded;
    return PaginationLoadState.loaded;
  }

  @override
  void dispose() {
    _mem.clear();
    _state.dispose();
    searchText.dispose();
    super.dispose();
  }
}
