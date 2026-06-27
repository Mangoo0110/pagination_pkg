# pagination_pkg

An in-memory pagination controller for Flutter presentation layers.

This package manages paginated item memory, load state, request coordination,
and presentation-friendly issue reporting. It does not perform HTTP requests,
persist data, own navigation, or decide domain-specific search/filter rules.

## Features

- Infinite-scroll style page loading.
- Page-number and cursor inputs through `OnDemandPage`.
- Optional query forwarding for app-owned search requests.
- In-memory deduplication and updates by stable item key.
- Maximum in-memory capacity for long lists.
- Load states for loading, refresh, loaded, empty, all-loaded, and error.
- Labeled issues through `onIssue`: `info`, `warning`, `error`, `critical`.
- Read-only `items` snapshots for app-side filtering and rendering.

## Responsibility Boundary

The package handles:

- in-memory paginated items
- page request state
- duplicate request prevention
- refresh and load-more coordination
- error and issue signaling


## Usage

```dart
final controller = InfinityScrollPaginationController<int, User>(
  perPageLimit: 10,
  maxCapacityCount: 100,
  onIssue: (issue) {
    // issue.label: info, warning, error, critical
    // issue.message: user-facing or loggable detail
  },
  onDemandPageCall: ({required onDemandPage}) async {
    final response = await userRepository.fetchUsers(
      page: onDemandPage.pageNo,
      perPage: onDemandPage.limit,
      query: onDemandPage.query,
    );

    return PaginationPage<int, User>(
      page: response.page,
      items: {
        for (final user in response.users) user.id: user,
      },
      hasMore: response.page < response.totalPages,
      totalItems: response.total,
      totalPages: response.totalPages,
    );
  },
);
```

Load pages:

```dart
await controller.loadNextPage();
```

Refresh with a query:

```dart
await controller.refreshWithQuery('ada');
```

Filter locally in the app:

```dart
final visibleUsers = controller.items.where((user) {
  return user.name.toLowerCase().contains(query.toLowerCase());
}).toList();
```

The `items` getter returns a read-only snapshot of the current in-memory items.

## Error Handling

Return `PaginationError` from `onDemandPageCall` when a page request fails:

```dart
return PaginationError<int, User>(
  page: onDemandPage.pageNo,
  message: 'Network unavailable',
);
```

For critical errors that invalidate current in-memory data:

```dart
return PaginationError<int, User>(
  page: onDemandPage.pageNo,
  message: 'Data source changed',
  isCritical: true,
);
```

Critical errors clear in-memory items and emit a `critical` issue. Non-critical
errors keep existing items and emit an `error` issue.

## Notes

- `search()` is deprecated. Use `refreshWithQuery()` for network-backed query
  refreshes, or filter `controller.items` directly in your app.
- `PaginationLoadState.nopages` is deprecated. Use `PaginationLoadState.noPages`.
