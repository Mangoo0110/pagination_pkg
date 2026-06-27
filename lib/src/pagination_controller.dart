import 'package:pagination_pkg/src/pagination_engine.dart';

import 'cache/infinity_scroll_pagination_mem.dart';

/// In-memory pagination controller keyed by [ItemUniqueKey].
///
/// [ItemUniqueKey] should be a stable unique identifier for each [ItemData].
/// The controller uses it to merge repeated items across page responses and
/// avoid duplicate entries in memory.
final class InfiniteScrollPaginationController<ItemUniqueKey, ItemData>
    extends PaginationEngine<ItemUniqueKey, ItemData> {
  InfiniteScrollPaginationController({
    super.items,
    super.perPageLimit,
    required super.onDemandPageCall,
    super.onIssue,
    required int maxCapacityCount,
  }) : super(
         mem: InfiniteScrollPaginationMem<ItemUniqueKey, ItemData>(
           onMemUpdate: () {},
           perPageLimit: perPageLimit,
           maxCapacity: maxCapacityCount,
         ),
       );
}
