
// import 'dart:math';

// import 'package:flutter/material.dart';

// import 'pagination_mem.dart';
// import '../page_fetch_response.dart';

// class MultiPagePaginationMem<ItemUniqueKey, ItemData> extends PaginationMem<ItemUniqueKey, ItemData> {
//   final ValueNotifier<List<PaginationPage<ItemData>>> pages = ValueNotifier([]);

//   MultiPagePaginationMem({required super.perPageLimit, required super.onMemUpdate});

//   /// Recursive calls***
//   /// This method `intentionally` does not notify any listeners for ui updates or anything else...
//   @override
//   void addNextPage(Map<ItemUniqueKey, ItemData> items) {
//     debugPrint("Adding items: ${items.length}");
//     // Base case to end recursion
//     if(items.isEmpty) {
//       debugPrint("No more items to add");
//       onMemUpdate();
//       return;
//     }
//     // Case 1: Add to last page
//     if(pages.value.isNotEmpty && pages.value.last.items.length < perPageLimit) {
//       final int emptySlots = perPageLimit - pages.value.last.items.length;
//       pages.value.last.items.addAll(items.getRange(0, min(items.length, emptySlots)));
//       addNextPage(items.getRange(emptySlots, items.length).toList());
//       debugPrint("Filling($emptySlots) last page: ${pages.value.last}");
//       return;
//     }
//     // Case 2: Add to new page
    
//     final page = PaginationPage<ItemData>(
//       items: items.getRange(0, min(items.length, perPageLimit)).toList(),
//       page: pages.value.isNotEmpty ? pages.value.last.page + 1 : firstPageVal,
//     );
//     pages.value.add(page);
//     debugPrint("Added new page, items: ${page.items.length}");
//     addNextPage(items.getRange(pages.value.last.items.length, items.length).toList());
//   }


//   // Recursive calls***
//   // This method `intentionally` does not notify any listeners for ui updates or anything else...
//   @override
//   void addFrontPage(List<ItemData> items) {
//     // Base case
//     if(items.isEmpty || pages.value.isNotEmpty && pages.value.first.page <= firstPageVal) {
//       onMemUpdate();
//       return;
//     }
//     // Case 1: Add to last front page
//     if(pages.value.isNotEmpty && pages.value.first.items.length < perPageLimit) {
//       final int emptySlots = perPageLimit - pages.value.first.items.length;
//       pages.value.first.items.addAll(items.getRange(0, min(items.length, emptySlots)));
//       addFrontPage(items.getRange(emptySlots, items.length).toList());
//       return;
//     }
//     // Case 2: Add to new page
//     if(pages.value.first.page - 1 < 0) {
//       return;
//     }
//     final page = PaginationPage<ItemData>(
//       items: items.getRange(0, min(items.length, perPageLimit)).toList(),
//       page: pages.value.isNotEmpty ? pages.value.first.page - 1 : firstPageVal,
//     );
//     pages.value.insert(page.page, page);
//     addFrontPage(items.getRange(pages.value.first.items.length, items.length).toList());
//   }
  

  
//   @override
//   void deleteItemAt(int index) {
//     if(itemAt(index) == null) {
//       return;
//     } else {
//       pages.value[index ~/ perPageLimit].items.removeAt(index % perPageLimit);

//       // after removing an item, adjust the page accordingly
      
//     }
//   }
  
//   @override
//   ItemData? itemAt(int index) {
//     if(pages.value.isEmpty) {
//       return null;
//     }
//     return pages.value[index ~/ perPageLimit].items[index % perPageLimit];
//   }
  
//   @override
//   int get length => pages.value.length * perPageLimit - (pages.value.isEmpty ? 0 : (perPageLimit - pages.value.last.items.length));
  
//   @override
//   void updateItemAt(int index, ItemData item) {
//     if(itemAt(index) == null) {
//       return;
//     } else {
//       pages.value[index ~/ perPageLimit].items[index % perPageLimit] = item;
//     }
//   }
  
//   @override
//   void clear() {
//     pages.value.clear();
//     onMemUpdate();
//   }
  
//   @override
//   ItemData? get first => pages.value.isEmpty ? null : pages.value.first.items.first;
  
//   @override
//   bool get isEmpty => pages.value.isEmpty || pages.value.last.items.isEmpty;
  
//   @override
//   ItemData? get last => pages.value.isEmpty ? null : pages.value.last.items.last;
  
//   @override
//   int get nextPageToFetch => pages.value.isEmpty ? firstPageVal : pages.value.last.page + 1;
  
//   @override
//   int get previousPageToFetch => max(firstPageVal, pages.value.isEmpty ? firstPageVal : pages.value.first.page - 1);

// }

