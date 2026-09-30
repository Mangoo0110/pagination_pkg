import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagination_pkg/pagination_pkg.dart';
import 'package:pagination_pkg/src/cache/infinity_scroll_pagination_mem.dart';

void main() {
  group('InfinityScrollPaginationMem', () {
    test('keeps only maxCapacity items when adding next pages', () {
      var updateCount = 0;
      final mem = InfiniteScrollPaginationMem<int, String>(
        perPageLimit: 2,
        maxCapacity: 3,
        onMemUpdate: () => updateCount++,
      );

      mem.addNextPage({1: 'one', 2: 'two'});
      mem.addNextPage({3: 'three', 4: 'four'});

      expect(mem.length, 3);
      expect(mem.itemAt(0), 'two');
      expect(mem.itemAt(1), 'three');
      expect(mem.itemAt(2), 'four');
      expect(mem.nextPageToFetch, 3);
      expect(mem.previousPageToFetch, 1);
      expect(updateCount, 2);
    });

    test('keeps item order when adding previous pages', () {
      final mem = InfiniteScrollPaginationMem<int, String>(
        perPageLimit: 2,
        maxCapacity: 4,
        onMemUpdate: () {},
      );

      mem.addNextPage({3: 'three', 4: 'four'});
      mem.addFrontPage({1: 'one', 2: 'two'});

      expect(mem.length, 4);
      expect(mem.itemAt(0), 'one');
      expect(mem.itemAt(1), 'two');
      expect(mem.itemAt(2), 'three');
      expect(mem.itemAt(3), 'four');
    });

    test('updates duplicate keys instead of adding duplicate items', () {
      final mem = InfiniteScrollPaginationMem<int, String>(
        perPageLimit: 2,
        maxCapacity: 5,
        onMemUpdate: () {},
      );

      mem.addNextPage({1: 'one', 2: 'two'});
      mem.addNextPage({2: 'TWO', 3: 'three'});

      expect(mem.length, 3);
      expect(mem.itemAt(0), 'one');
      expect(mem.itemAt(1), 'TWO');
      expect(mem.itemAt(2), 'three');
    });

    test('rebuilds key indexes after delete', () {
      final mem = InfiniteScrollPaginationMem<int, String>(
        perPageLimit: 2,
        maxCapacity: 5,
        onMemUpdate: () {},
      );

      mem.addNextPage({1: 'one', 2: 'two', 3: 'three'});
      mem.deleteItemAt(0);
      mem.upsertItem(key: 3, item: 'THREE');

      expect(mem.length, 2);
      expect(mem.itemAt(0), 'two');
      expect(mem.itemAt(1), 'THREE');
    });

    test('returns null for out of range reads', () {
      final mem = InfiniteScrollPaginationMem<int, String>(
        perPageLimit: 2,
        maxCapacity: 5,
        onMemUpdate: () {},
      );

      expect(mem.itemAt(-1), isNull);
      expect(mem.itemAt(0), isNull);

      mem.addNextPage({1: 'one'});

      expect(mem.itemAt(1), isNull);
    });

    test('notifies when updating and upserting items', () {
      var updateCount = 0;
      final mem = InfiniteScrollPaginationMem<int, String>(
        perPageLimit: 2,
        maxCapacity: 5,
        onMemUpdate: () => updateCount++,
      );

      mem.addNextPage({1: 'one'});
      mem.updateItemAt(0, 'ONE');
      mem.upsertItem(key: 2, item: 'two');
      mem.upsertItem(key: 2, item: 'TWO');

      expect(updateCount, 4);
      expect(mem.itemAt(0), 'ONE');
      expect(mem.itemAt(1), 'TWO');
    });

    test('returns read-only item snapshots in display order', () {
      final mem = InfiniteScrollPaginationMem<int, String>(
        perPageLimit: 2,
        maxCapacity: 5,
        onMemUpdate: () {},
      );

      mem.addNextPage({1: 'one', 2: 'two'});

      expect(mem.items, ['one', 'two']);
      expect(() => mem.items.add('three'), throwsUnsupportedError);
    });
  });

  group('InfinityScrollPaginationController', () {
    test('stops loading next pages when response hasMore is false', () async {
      final requestedPages = <int>[];
      final controller = InfiniteScrollPaginationController<int, String>(
        perPageLimit: 2,
        maxCapacityCount: 10,
        onDemandPageCall: ({required onDemandPage}) async {
          requestedPages.add(onDemandPage.pageNo);
          return PaginationPage<int, String>(
            page: onDemandPage.pageNo,
            items: {onDemandPage.pageNo: 'page-${onDemandPage.pageNo}'},
            hasMore: false,
            totalPages: onDemandPage.pageNo,
          );
        },
      );

      await controller.loadNextPage();
      await controller.loadNextPage();

      expect(requestedPages, [1]);
      expect(controller.length, 1);
      expect(controller.state.value, PaginationState.allLoaded);

      controller.dispose();
    });

    test('keeps empty page as a terminal page', () async {
      final requestedPages = <int>[];
      final controller = InfiniteScrollPaginationController<int, String>(
        perPageLimit: 2,
        maxCapacityCount: 10,
        onDemandPageCall: ({required onDemandPage}) async {
          requestedPages.add(onDemandPage.pageNo);
          return PaginationPage<int, String>(
            page: onDemandPage.pageNo,
            items: const {},
          );
        },
      );

      await controller.loadNextPage();
      await controller.loadNextPage();

      expect(requestedPages, [1]);
      expect(controller.length, 0);
      expect(controller.state.value, PaginationState.allLoaded);

      controller.dispose();
    });

    test(
      'stores non-critical errors without clearing previous items',
      () async {
        var callCount = 0;
        final issues = <PaginationIssue>[];
        final controller = InfiniteScrollPaginationController<int, String>(
          perPageLimit: 2,
          maxCapacityCount: 10,
          onIssue: issues.add,
          onDemandPageCall: ({required onDemandPage}) async {
            callCount++;
            if (callCount == 1) {
              return PaginationPage<int, String>(
                page: onDemandPage.pageNo,
                items: const {1: 'one'},
              );
            }
            return PaginationError<int, String>(
              page: onDemandPage.pageNo,
              message: 'Network unavailable',
            );
          },
        );

        await controller.loadNextPage();
        await controller.loadNextPage();

        expect(controller.length, 1);
        expect(controller.latestError?.message, 'Network unavailable');
        expect(controller.latestError?.isCritical, isFalse);
        expect(issues.single.label, PaginationIssueLabel.error);
        expect(issues.single.message, 'Network unavailable');
        expect(controller.state.value, PaginationState.error);

        controller.dispose();
      },
    );

    test('clears previous items on critical errors', () async {
      final issues = <PaginationIssue>[];
      final controller = InfiniteScrollPaginationController<int, String>(
        items: const {1: 'one'},
        perPageLimit: 2,
        maxCapacityCount: 10,
        onIssue: issues.add,
        onDemandPageCall: ({required onDemandPage}) async {
          return PaginationError<int, String>(
            page: onDemandPage.pageNo,
            message: 'Data source changed',
            isCritical: true,
          );
        },
      );

      await controller.loadNextPage();

      expect(controller.length, 0);
      expect(controller.latestError?.message, 'Data source changed');
      expect(controller.latestError?.isCritical, isTrue);
      expect(issues.single.label, PaginationIssueLabel.critical);
      expect(issues.single.message, 'Data source changed');
      expect(controller.state.value, PaginationState.error);

      controller.dispose();
    });

    test('clears latest error after a successful page load', () async {
      var callCount = 0;
      final controller = InfiniteScrollPaginationController<int, String>(
        perPageLimit: 2,
        maxCapacityCount: 10,
        onDemandPageCall: ({required onDemandPage}) async {
          callCount++;
          if (callCount == 1) {
            return PaginationError<int, String>(
              page: onDemandPage.pageNo,
              message: 'Temporary failure',
            );
          }
          return PaginationPage<int, String>(
            page: onDemandPage.pageNo,
            items: const {1: 'one'},
          );
        },
      );

      await controller.loadNextPage();
      await controller.loadNextPage();

      expect(controller.latestError, isNull);
      expect(controller.length, 1);
      expect(controller.state.value, PaginationState.loaded);

      controller.dispose();
    });

    test('prevents duplicate next-page requests while loading', () async {
      var callCount = 0;
      final completer = Completer<PageFetchResponse<int, String>>();
      final issues = <PaginationIssue>[];
      final controller = InfiniteScrollPaginationController<int, String>(
        perPageLimit: 2,
        maxCapacityCount: 10,
        onIssue: issues.add,
        onDemandPageCall: ({required onDemandPage}) {
          callCount++;
          return completer.future;
        },
      );

      final firstLoad = controller.loadNextPage();

      expect(controller.isRequestInFlight, isTrue);

      final secondLoad = controller.loadNextPage();

      expect(callCount, 1);
      expect(issues.single.label, PaginationIssueLabel.warning);
      expect(
        issues.single.message,
        'Load more was skipped because a page request is already running.',
      );

      completer.complete(
        PaginationPage<int, String>(page: 1, items: const {1: 'one'}),
      );

      await Future.wait([firstLoad, secondLoad]);

      expect(controller.isRequestInFlight, isFalse);
      expect(controller.length, 1);
      expect(controller.state.value, PaginationState.loaded);

      controller.dispose();
    });

    test(
      'emits an info issue when loading after all pages are loaded',
      () async {
        final issues = <PaginationIssue>[];
        final controller = InfiniteScrollPaginationController<int, String>(
          perPageLimit: 2,
          maxCapacityCount: 10,
          onIssue: issues.add,
          onDemandPageCall: ({required onDemandPage}) async {
            return PaginationPage<int, String>(
              page: onDemandPage.pageNo,
              items: const {1: 'one'},
              hasMore: false,
            );
          },
        );

        await controller.loadNextPage();
        await controller.loadNextPage();

        expect(issues.single.label, PaginationIssueLabel.info);
        expect(
          issues.single.message,
          'Load more was skipped because no more pages are available.',
        );

        controller.dispose();
      },
    );

    test('exposes read-only items for app-side filtering', () async {
      final controller = InfiniteScrollPaginationController<int, String>(
        perPageLimit: 3,
        maxCapacityCount: 10,
        onDemandPageCall: ({required onDemandPage}) async {
          return PaginationPage<int, String>(
            page: onDemandPage.pageNo,
            items: const {1: 'Ada', 2: 'Grace', 3: 'Alan'},
          );
        },
      );

      await controller.loadNextPage();

      final filtered = controller.items
          .where((name) => name.toLowerCase().startsWith('a'))
          .toList();

      expect(controller.items, ['Ada', 'Grace', 'Alan']);
      expect(filtered, ['Ada', 'Alan']);
      expect(() => controller.items.add('Margaret'), throwsUnsupportedError);

      controller.dispose();
    });

    test('refresh reloads the first page and clears previous items', () async {
      final requests = <OnDemandPage<String>>[];
      final controller = InfiniteScrollPaginationController<int, String>(
        perPageLimit: 2,
        maxCapacityCount: 10,
        onDemandPageCall: ({required onDemandPage}) async {
          requests.add(onDemandPage);
          return PaginationPage<int, String>(
            page: onDemandPage.pageNo,
            items: {onDemandPage.pageNo: 'page-${onDemandPage.pageNo}'},
          );
        },
      );

      await controller.loadNextPage();
      await controller.refresh();

      expect(requests.map((request) => request.pageNo), [1, 1]);
      expect(requests.last.intent, PaginationFetchIntent.initial);
      expect(requests.last.cursorItem, isNull);
      expect(controller.items, ['page-1']);

      controller.dispose();
    });

    test('passes item context to next-page requests', () async {
      final requests = <OnDemandPage<String>>[];
      final controller = InfiniteScrollPaginationController<int, String>(
        perPageLimit: 1,
        maxCapacityCount: 10,
        onDemandPageCall: ({required onDemandPage}) async {
          requests.add(onDemandPage);
          return PaginationPage<int, String>(
            page: onDemandPage.pageNo,
            items: {onDemandPage.pageNo: 'item-${onDemandPage.pageNo}'},
          );
        },
      );

      await controller.loadNextPage();
      await controller.loadNextPage();

      expect(requests[0].intent, PaginationFetchIntent.next);
      expect(requests[0].cursorItem, isNull);

      expect(requests[1].intent, PaginationFetchIntent.next);
      expect(requests[1].cursorItem, 'item-1');

      controller.dispose();
    });

    test('passes cursor item to previous-page requests', () async {
      final requests = <OnDemandPage<String>>[];
      final controller = InfiniteScrollPaginationController<int, String>(
        items: const {1: 'item-1', 2: 'item-2'},
        perPageLimit: 1,
        maxCapacityCount: 1,
        onDemandPageCall: ({required onDemandPage}) async {
          requests.add(onDemandPage);
          return PaginationPage<int, String>(
            page: onDemandPage.pageNo,
            items: {onDemandPage.pageNo: 'item-${onDemandPage.pageNo}'},
          );
        },
      );

      await controller.loadPreviousPage();

      expect(requests.last.intent, PaginationFetchIntent.previous);
      expect(requests.last.cursorItem, 'item-2');

      controller.dispose();
    });
  });

  group('PaginationPage', () {
    test('exposes generic pagination metadata', () {
      final page = PaginationPage<int, String>(
        page: 2,
        items: const {1: 'one'},
        hasMore: false,
        totalItems: 3,
        totalPages: 2,
      );

      expect(page.total, 1);
      expect(page.reachedEnd, isTrue);
      expect(page.totalItems, 3);
      expect(page.totalPages, 2);
    });

    test('labels errors from severity', () {
      final error = PaginationError<int, String>(
        page: 1,
        message: 'Temporary failure',
      );
      final criticalError = PaginationError<int, String>(
        page: 1,
        message: 'Data changed',
        isCritical: true,
      );

      expect(error.label, PaginationIssueLabel.error);
      expect(criticalError.label, PaginationIssueLabel.critical);
    });
  });
}
