import 'package:pagination_pkg/src/pagination_engine.dart';

import 'cache/infinity_scroll_pagination_mem.dart';
import 'cache/multi_page_pagination_mem.dart';

// class MultiPagePaginationController<T> extends PaginationEngine<T> {
//   MultiPagePaginationController({
//     super.items,
//     super.perPageLimit,
//     required super.onDemandPageCall,
//   }) : super(
//          mem: MultiPagePaginationMem(
//            perPageLimit: perPageLimit,
//            onMemUpdate: () {},
//          ),
//        );
// }


class InfinityScrollPaginationController<ItemUniqueKey, ItemData> extends PaginationEngine<ItemUniqueKey, ItemData> {
  InfinityScrollPaginationController({
    super.items,
    super.perPageLimit,
    required super.onDemandPageCall,
    required int maxCapacityCount,
  }) : super(
         mem: InfinityScrollPaginationMem<ItemUniqueKey, ItemData>(
           onMemUpdate: () {},
           perPageLimit: perPageLimit,
           maxCapacity: maxCapacityCount,
         ),
       );
}
