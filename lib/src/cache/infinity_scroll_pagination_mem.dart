

import 'dart:math';

import 'pagination_mem.dart';

class InfinityScrollPaginationMem<ItemUniqueKey, ItemData> extends PaginationMem<ItemUniqueKey, ItemData> {
  InfinityScrollPaginationMem({required super.perPageLimit, required super.onMemUpdate, required this.maxCapacity});
  
  final int maxCapacity;
  int _removedFromFront = 0;
  final List<ItemData> _items = [];
  final Map<ItemUniqueKey, int> _keyIndexMap = {};
  
  @override
  void addFrontPage(Map<ItemUniqueKey, ItemData> items) {
    int addedNew = 0;
    // filter items that are already in the list using the keyIndexMap
    for (final entry in items.entries) {
      final key = entry.key;
      final item = entry.value;
      if (_keyIndexMap.containsKey(key)) {
        // If the item is already in the list, update it
        final index = _keyIndexMap[key]!;
        if(!_isOutOfBound(index)) {
          _items[index] = item;
          continue;
        } else {
          // If the index is out of bound, it means the item was removed from the list. We can add it again.
          _keyIndexMap.remove(key);
        }
      }
      _items.insert(0, item);
      addedNew++;
    }

    _removedFromFront -= min(addedNew, _removedFromFront);
    onMemUpdate();
  }

  @override
  void addNextPage(Map<ItemUniqueKey, ItemData> items) {
    // filter items that are already in the list using the keyIndexMap
    for (final entry in items.entries) {
      final key = entry.key;
      final item = entry.value;
      if (_keyIndexMap.containsKey(key)) {
        // If the item is already in the list, update it
        final index = _keyIndexMap[key]!;
        if(!_isOutOfBound(index)) {
          _items[index] = item;
          continue;
        } else {
          // If the index is out of bound, it means the item was removed from the list. We can add it again.
          _keyIndexMap.remove(key);
        }
      }
      _items.add(item);
      _keyIndexMap[key] = _items.length - 1;
    }
    onMemUpdate();
  }

  @override
  void clear() {
    _items.clear();
  }

  @override
  void deleteItemAt(int index) {
    _items.removeAt(index);
    onMemUpdate();
  }

  @override
  ItemData? get first => _items.isEmpty ? null : _items.first;

  @override
  bool get isEmpty => _items.isEmpty;

  @override
  ItemData? itemAt(int index) {
    if(_items.isEmpty) {
      return null;
    }
    return _items[index];
  }

  @override
  ItemData? get last => _items.isEmpty ? null : _items.last;

  @override
  int get length => _items.length;

  @override
  int get nextPageToFetch => (_items.length / perPageLimit).floor() + (_items.length % perPageLimit == 0 ? 1 : 0);

  @override
  int get previousPageToFetch => (_removedFromFront / perPageLimit).floor() + (_removedFromFront % perPageLimit == 0 ? 1 : 0);

  @override
  void updateItemAt(int index, ItemData item) {
    if(!_isOutOfBound(index)) {
      _items[index] = item;
    }
  }

  /// Returns true if index is out of bound and you should not use that index to read data from the list.
  /// 
  /// Else returns false
  bool _isOutOfBound(int index) {
    if(index < 0 || index >= _items.length) return true;
    return false;
  }
}