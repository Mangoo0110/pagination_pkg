import 'package:flutter_test/flutter_test.dart';
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
}
