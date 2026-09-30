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

  factory PaginationIssue.fromError(PaginationError<dynamic, dynamic> error) {
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

/// A successfully fetched page.
///
/// [ItemUniqueKey] is the stable unique key for an item, such as an id, uuid,
/// slug, or any value that uniquely identifies one [ItemData]. The package uses
/// this key to update existing items instead of storing duplicates.
class PaginationPage<ItemUniqueKey, ItemData>
    extends PageFetchResponse<ItemUniqueKey, ItemData> {
  /// Page items keyed by their stable unique item key.
  ///
  /// This is a [Map] instead of a [List] so the in-memory cache can prevent
  /// duplicate [ItemData] entries across pages. Choosing the right key is the
  /// caller's responsibility: every logical item should always use the same
  /// [ItemUniqueKey], even if it appears again in another page response.
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
    return 'PaginationPage(page: $page, total: $total, hasMore: $hasMore, totalItems: $totalItems, totalPages: $totalPages)';
  }
}

class PaginationError<ItemUniqueKey, ItemData>
    extends PageFetchResponse<ItemUniqueKey, ItemData> {
  final String message;

  /// If critical, the current in-memory data is considered invalid and should
  /// be cleared. If not critical, existing in-memory data remains available.
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
