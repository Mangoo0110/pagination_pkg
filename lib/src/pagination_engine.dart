import 'package:flutter/material.dart';
import 'package:pagination_pkg/src/logger.dart';
import 'cache/pagination_mem.dart';
import 'page_fetch_response.dart';

enum PaginationState {
  idle,
  loading,
  refreshing,
  loaded,
  updated,
  allLoaded,
  noPages,
  error,
}

/// Explains why the package is requesting this page.
///
/// The package does not store backend cursor tokens. If a backend needs a
/// cursor, keep that value on your item model and read it from
/// [OnDemandPage.cursorItem].
enum PaginationFetchIntent { initial, next, previous }

sealed class OnDemandPage<ItemData> {
  /// Requested item count. Match this with your backend page size or limit.
  final int limit;

  /// Logical page number tracked by the in-memory pagination window.
  ///
  /// Cursor-based APIs may ignore this and use [cursorItem] instead.
  final int pageNo;

  /// Whether this request is for the initial page, next page, or previous page.
  final PaginationFetchIntent intent;

  /// The only cached item relevant to this request.
  ///
  /// For [PaginationFetchIntent.next], this is the current last item and should
  /// usually become an `after` cursor. For [PaginationFetchIntent.previous],
  /// this is the current first item and should usually become a `before`
  /// cursor. For [PaginationFetchIntent.initial], this is null.
  final ItemData? cursorItem;

  OnDemandPage({
    required this.limit,
    required this.pageNo,
    required this.intent,
    this.cursorItem,
  });
}

class LoadNextPage<ItemData> extends OnDemandPage<ItemData> {
  /// Fetches items after the current in-memory tail.
  LoadNextPage({required super.limit, required super.pageNo, super.cursorItem})
    : super(intent: PaginationFetchIntent.next);
}

class LoadPreviousPage<ItemData> extends OnDemandPage<ItemData> {
  /// Fetches items before the current in-memory head.
  LoadPreviousPage({
    required super.limit,
    required super.pageNo,
    super.cursorItem,
  }) : super(intent: PaginationFetchIntent.previous);
}

class RefreshPage<ItemData> extends OnDemandPage<ItemData> {
  /// Fetches a fresh first page without using an existing item as a cursor.
  RefreshPage({required super.limit, required super.pageNo})
    : super(intent: PaginationFetchIntent.initial);
}

class PaginationEngine<ItemUniqueKey, ItemData> extends ChangeNotifier {
  PaginationEngine({
    Map<ItemUniqueKey, ItemData>? items,
    required PaginationMem<ItemUniqueKey, ItemData> mem,
    required this.onDemandPageCall,
    this.onIssue,
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

  final void Function(PaginationIssue issue)? onIssue;

  final ValueNotifier<PaginationState> _state = ValueNotifier(
    PaginationState.idle,
  );
  PaginationError<ItemUniqueKey, ItemData>? _latestError;
  bool _isRequestInFlight = false;

  ValueNotifier<PaginationState> get state => _state;

  PaginationError<ItemUniqueKey, ItemData>? get latestError => _latestError;

  bool get isRequestInFlight => _isRequestInFlight;

  /// Defaults to 10.
  ///
  /// This value is passed to [onDemandPageCall] as [OnDemandPage.limit] and is
  /// also used as the unit for calculating the next/previous logical page
  /// number. The package does not reject or split larger page responses. All
  /// unique items returned by a page response are accepted, then the in-memory
  /// cache trims to its configured capacity.
  final int perPageLimit;

  int get totalItemsCount => _mem.length;

  ItemData? itemAt(int index) => _mem.itemAt(index);

  int get length => _mem.length;

  List<ItemData> get items => _mem.items;

  bool get isEmpty => _mem.isEmpty;

  void deleteItemAt(int index) => _mem.deleteItemAt(index);

  void updateItemAt(int index, ItemData item) => _mem.updateItemAt(index, item);

  Future<PaginationPage<ItemUniqueKey, ItemData>?> requestData({
    required OnDemandPage<ItemData> onDemandPage,
  }) async {
    if (_isRequestInFlight) {
      _emitIssue(
        const PaginationIssue(
          message: 'A page request is already running.',
          label: PaginationIssueLabel.warning,
        ),
      );
      return null;
    }

    _isRequestInFlight = true;
    PaginationPage<ItemUniqueKey, ItemData>? page;
    // await debouncer.run(() async {

    // });
    try {
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
        _clearError();
        page = res;
      }
    } finally {
      _isRequestInFlight = false;
    }
    return page;
  }

  /// Sets the state to [PaginationState.refreshing]
  /// Clears the [PaginationMem]
  ///
  /// Triggers [notifyListeners], as memory along with state has changed
  void setRefresh() {
    _clearError();
    _mem.clear();
    state.value = PaginationState.refreshing;
    notifyListeners();
  }

  /// Stores the latest error and moves the controller to [PaginationState.error].
  ///
  /// Critical errors clear the in-memory items. Non-critical errors keep the
  /// current items because no new page data was accepted.
  void setError({PaginationError<ItemUniqueKey, ItemData>? error}) {
    _latestError = error;
    if (error?.isCritical ?? false) {
      _mem.clear();
    }
    if (error != null) {
      _emitIssue(PaginationIssue.fromError(error));
    }
    state.value = PaginationState.error;
    notifyListeners();
  }

  /// Sets the state to [PaginationState.loading]
  /// #### NOTE: This does not trigger [notifyListeners]
  void setLoading() {
    state.value = PaginationState.loading;
  }

  /// Triggers [notifyListeners]
  void setNoPages() {
    state.value = PaginationState.noPages;
    notifyListeners();
  }

  /// Checks if current state is [PaginationState.allLoaded] or [PaginationState.noPages].
  bool _shouldTryLoadMore() {
    if (_isRequestInFlight) {
      _emitIssue(
        const PaginationIssue(
          message:
              'Load more was skipped because a page request is already running.',
          label: PaginationIssueLabel.warning,
        ),
      );
      return false;
    }
    if (state.value == PaginationState.allLoaded ||
        state.value == PaginationState.noPages) {
      _emitIssue(
        const PaginationIssue(
          message: 'Load more was skipped because no more pages are available.',
          label: PaginationIssueLabel.info,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _loadPage({
    required int pageNo,
    required OnDemandPage<ItemData> onDemandPage,
    required void Function(Map<ItemUniqueKey, ItemData> items) addItems,
    required PaginationState emptyState,
    bool reset = false,
  }) async {
    if (_isRequestInFlight) {
      _emitIssue(
        const PaginationIssue(
          message:
              'Load page was skipped because a page request is already running.',
          label: PaginationIssueLabel.warning,
        ),
      );
      return;
    }

    if (pageNo < _mem.firstPageVal) {
      _emitIssue(
        PaginationIssue(
          message: 'Page number must be ${_mem.firstPageVal} or greater.',
          label: PaginationIssueLabel.warning,
          page: pageNo,
        ),
      );
      return;
    }

    if (reset) {
      setRefresh();
    } else {
      state.value = PaginationState.loading;
    }

    final res = await requestData(onDemandPage: onDemandPage);

    if (res == null) {
      notifyListeners();
      return;
    }

    addItems(res.items);
    state.value = _stateForPage(res, emptyState: emptyState);
    notifyListeners();
  }

  Future<void> loadNextPage() async {
    // Guard
    if (!_shouldTryLoadMore()) {
      return;
    }

    await _loadPage(
      pageNo: _mem.nextPageToFetch,
      onDemandPage: LoadNextPage<ItemData>(
        limit: perPageLimit,
        pageNo: _mem.nextPageToFetch,
        cursorItem: _mem.last,
      ),
      addItems: _mem.addNextPage,
      emptyState: PaginationState.allLoaded,
    );
  }

  Future<void> loadPreviousPage() async {
    // Guard
    if (!_shouldTryLoadMore() ||
        (_mem.previousPageToFetch < _mem.firstPageVal)) {
      return;
    }

    await _loadPage(
      pageNo: _mem.previousPageToFetch,
      onDemandPage: LoadPreviousPage<ItemData>(
        limit: perPageLimit,
        pageNo: _mem.previousPageToFetch,
        cursorItem: _mem.first,
      ),
      addItems: _mem.addFrontPage,
      emptyState: PaginationState.allLoaded,
    );
  }

  Future<void> refresh() async {
    _logger.showLog("Refreshing...");
    await _loadPage(
      pageNo: 1,
      onDemandPage: RefreshPage<ItemData>(limit: perPageLimit, pageNo: 1),
      addItems: _mem.addNextPage,
      emptyState: PaginationState.noPages,
      reset: true,
    );
  }

  void upsertItem({required ItemUniqueKey key, required ItemData item}) {
    //state.value = PaginationState.loading;
    _mem.upsertItem(key: key, item: item);
    state.value = PaginationState.updated;
    notifyListeners();
  }

  PaginationState _stateForPage(
    PaginationPage<ItemUniqueKey, ItemData> page, {
    required PaginationState emptyState,
  }) {
    if (page.items.isEmpty) return emptyState;
    if (page.hasMore == false) return PaginationState.allLoaded;
    return PaginationState.loaded;
  }

  void _clearError() {
    _latestError = null;
  }

  void _emitIssue(PaginationIssue issue) {
    _logger.showLog('[${issue.label.name}] ${issue.message}');
    onIssue?.call(issue);
  }

  @override
  void dispose() {
    _mem.clear();
    _state.dispose();
    super.dispose();
  }
}
