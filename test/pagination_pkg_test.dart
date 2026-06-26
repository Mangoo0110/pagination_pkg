import 'package:flutter_test/flutter_test.dart';
import 'package:pagination_pkg/pagination_pkg.dart';
import 'package:pagination_pkg/src/cache/infinity_scroll_pagination_mem.dart';

void main() {
  group('InfinityScrollPaginationMem', () {
    test('keeps only maxCapacity items when adding next pages', () {
      var updateCount = 0;
      final mem = InfinityScrollPaginationMem<int, String>(
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
      final mem = InfinityScrollPaginationMem<int, String>(
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
      final mem = InfinityScrollPaginationMem<int, String>(
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
      final mem = InfinityScrollPaginationMem<int, String>(
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
      final mem = InfinityScrollPaginationMem<int, String>(
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
      final mem = InfinityScrollPaginationMem<int, String>(
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
  });

  group('InfinityScrollPaginationController', () {
    test('stops loading next pages when response hasMore is false', () async {
      final requestedPages = <int>[];
      final controller = InfinityScrollPaginationController<int, String>(
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
      expect(controller.state.value, PaginationLoadState.allLoaded);

      controller.dispose();
    });

    test('keeps empty page as a terminal page', () async {
      final requestedPages = <int>[];
      final controller = InfinityScrollPaginationController<int, String>(
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
      expect(controller.state.value, PaginationLoadState.allLoaded);

      controller.dispose();
    });

    test(
      'stores non-critical errors without clearing previous items',
      () async {
        var callCount = 0;
        final controller = InfinityScrollPaginationController<int, String>(
          perPageLimit: 2,
          maxCapacityCount: 10,
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
        expect(controller.state.value, PaginationLoadState.error);

        controller.dispose();
      },
    );

    test('clears previous items on critical errors', () async {
      final controller = InfinityScrollPaginationController<int, String>(
        items: const {1: 'one'},
        perPageLimit: 2,
        maxCapacityCount: 10,
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
      expect(controller.state.value, PaginationLoadState.error);

      controller.dispose();
    });

    test('clears latest error after a successful page load', () async {
      var callCount = 0;
      final controller = InfinityScrollPaginationController<int, String>(
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
      expect(controller.state.value, PaginationLoadState.loaded);

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
  });
}
