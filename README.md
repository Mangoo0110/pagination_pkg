# pagination_pkg

An in-memory pagination controller for Flutter presentation layers.

This package manages paginated item memory, load state, request coordination,
and presentation-friendly issue reporting. It does not perform HTTP requests,
persist data, own navigation, or decide domain-specific search/filter rules.

## Features

- Infinite-scroll style page loading.
- Logical page-number and item-cursor fetch context through `OnDemandPage`.
- In-memory deduplication and updates by stable item key.
- Maximum in-memory capacity for long lists.
- Load states for loading, refreshing, loaded, no-pages, all-loaded, and error.
- Labeled issues through `onIssue`: `info`, `warning`, `error`, `critical`.
- Read-only `items` snapshots for app-side filtering and rendering.

## Responsibility Boundary

The package handles:

- in-memory paginated items
- page request state
- duplicate request prevention
- refresh and next/previous page coordination
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
    );

    return PaginationPage<int, User>(
      page: response.page,
      items: {
        // The map key must uniquely identify the item.
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
await controller.loadPreviousPage();
```

Refresh:

```dart
await controller.refresh();
```

Filter locally in the app:

```dart
final visibleUsers = controller.items.where((user) {
  return user.name.toLowerCase().contains(query.toLowerCase());
}).toList();
```

The `items` getter returns a read-only snapshot of the current in-memory items.

## Page Size And Capacity

`perPageLimit` is a request hint and a page-number calculation unit. The package
passes it to `onDemandPageCall` as `onDemandPage.limit`, but it does not enforce
that the response contains exactly that many items.

If `perPageLimit` is `10` and a response returns `100` unique items, the package
accepts those items, deduplicates them by key, and then trims the in-memory list
to `maxCapacityCount`.

Example:

- `maxCapacityCount: 100`: all 100 items can remain in memory.
- `maxCapacityCount: 50`: the newest 50 remain after a next-page load.
- `maxCapacityCount: 10`: the newest 10 remain after a next-page load.

Logical page numbers are calculated from the known item count and
`perPageLimit`. So if 100 items are accepted with `perPageLimit: 10`, the next
logical page number advances as if 10 pages of data were loaded.

## Item Keys And Deduplication

`PaginationPage.items` is a `Map<ItemKey, ItemData>` instead of a `List` because
the package uses the map key to prevent duplicate items in memory.

The key is chosen by the app:

```dart
return PaginationPage<int, User>(
  page: response.page,
  items: {
    for (final user in response.users) user.id: user,
  },
);
```

Use a stable unique value for each logical item, such as a database id, uuid, or
slug. If the same item appears in multiple page responses with the same key, the
package updates the existing item instead of appending a duplicate.

Choosing the key is the developer's responsibility. If two different items use
the same key, one can overwrite the other. If the same item uses different keys
between requests, the package cannot detect it as a duplicate.

## Page And Item-Cursor Context

Every fetch receives an `OnDemandPage`. The important field for cursor-based
APIs is `intent`.

`intent` tells you which item should be used as the cursor source:

- `PaginationFetchIntent.next`: this is a next-page request. Use the last
  in-memory item for an `after` cursor.
- `PaginationFetchIntent.previous`: this is a previous-page request. Use the
  first in-memory item for a `before` cursor.
- `PaginationFetchIntent.initial`: this is a refresh/first-page request. Do not
  send an item cursor.

The package does not store backend cursor tokens separately. If your backend
uses cursors, keep the cursor/id/timestamp on your item model.

```dart
onDemandPage.pageNo;       // logical page number tracked by the package
onDemandPage.limit;        // requested page size
onDemandPage.intent;       // initial, next, or previous
onDemandPage.cursorItem;   // relevant cursor item, or null for initial
```

For page-number APIs, use the logical `pageNo`:

```dart
fetchUsers(
  page: onDemandPage.pageNo,
  perPage: onDemandPage.limit,
);
```

For item-cursor APIs:

```dart
final cursorItem = onDemandPage.cursorItem;

fetchUsers(
  afterCursor: onDemandPage.intent == PaginationFetchIntent.next
      ? cursorItem?.cursor
      : null,
  beforeCursor: onDemandPage.intent == PaginationFetchIntent.previous
      ? cursorItem?.cursor
      : null,
  limit: onDemandPage.limit,
);
```

Example item model:

```dart
class User {
  final int id;
  final String name;
  final String cursor;

  User({
    required this.id,
    required this.name,
    required this.cursor,
  });
}
```

Expected method behavior:

```dart
await controller.loadNextPage();
// intent: PaginationFetchIntent.next
// cursorItem: current last item in memory

await controller.loadPreviousPage();
// intent: PaginationFetchIntent.previous
// cursorItem: current first item in memory

await controller.refresh();
// intent: PaginationFetchIntent.initial
// cursorItem: null
```

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

- Search and filtering are app-owned. Use `controller.items` for local filtering,
  or close over your app query state inside `onDemandPageCall`.
