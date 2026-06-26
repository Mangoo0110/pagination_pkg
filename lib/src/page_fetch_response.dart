sealed class PageFetchResponse<ItemUniqueKey, ItemData> {
  final int page;
  const PageFetchResponse({required this.page});
}

enum PaginationIssueLabel { info, warning, error, critical }

class PaginationIssue {
  const PaginationIssue({
    required this.message,
    required this.label,
    this.page,
  });

  factory PaginationIssue.fromError(PaginationError error) {
    return PaginationIssue(
      message: error.message,
      label: error.label,
      page: error.page,
    );
  }

  final String message;
  final PaginationIssueLabel label;
  final int? page;
}

class PaginationPage<ItemUniqueKey, ItemData>
    extends PageFetchResponse<ItemUniqueKey, ItemData> {
  final Map<ItemUniqueKey, ItemData> items;
  final bool? hasMore;
  final int? totalItems;
  final int? totalPages;

  PaginationPage({
    required this.items,
    required super.page,
    this.hasMore,
    this.totalItems,
    this.totalPages,
  });

  int get total => items.length;

  bool get reachedEnd => items.isEmpty || hasMore == false;

  @override
  String toString() {
    return 'PaginationPage(items: $items, page: $page, total: $total, hasMore: $hasMore, totalItems: $totalItems, totalPages: $totalPages)';
  }
}

class PaginationError<ItemUniqueKey, ItemData>
    extends PageFetchResponse<ItemUniqueKey, ItemData> {
  final String message;

  /// If critical, means previous data is not valid anymore and should be cleared.
  /// If not critical, previous data is still valid and new data will be added to it.
  final bool isCritical;
  PaginationError({
    required super.page,
    required this.message,
    this.isCritical = false,
  });

  PaginationIssueLabel get label {
    return isCritical
        ? PaginationIssueLabel.critical
        : PaginationIssueLabel.error;
  }
}
