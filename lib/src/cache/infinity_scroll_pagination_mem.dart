import 'dart:math';

import 'pagination_mem.dart';

class InfiniteScrollPaginationMem<ItemUniqueKey, ItemData>
    extends PaginationMem<ItemUniqueKey, ItemData> {
  InfiniteScrollPaginationMem({
    required super.perPageLimit,
    required super.onMemUpdate,
    required this.maxCapacity,
  }) {
    if (maxCapacity <= 0) {
      throw ArgumentError.value(
        maxCapacity,
        'maxCapacity',
        'Must be greater than zero.',
      );
    }
  }

  final int maxCapacity;
  int _removedFromFront = 0;
  final List<ItemData> _items = [];
  final List<ItemUniqueKey> _keys = [];
  final Map<ItemUniqueKey, int> _keyIndexMap = {};

  @override
  void addFrontPage(Map<ItemUniqueKey, ItemData> items) {
    var addedNew = 0;
    for (final entry in items.entries.toList().reversed) {
      final key = entry.key;
      final item = entry.value;
      if (_keyIndexMap.containsKey(key)) {
        final index = _keyIndexMap[key]!;
        if (!_isOutOfBound(index)) {
          _items[index] = item;
          continue;
        }
      }
      _items.insert(0, item);
      _keys.insert(0, key);
      addedNew++;
    }
    _removedFromFront -= min(addedNew, _removedFromFront);
    _trimBackToCapacity();
    _rebuildIndexMap();
    onMemUpdate();
  }

  @override
  void addNextPage(Map<ItemUniqueKey, ItemData> items) {
    for (final entry in items.entries) {
      final key = entry.key;
      final item = entry.value;
      if (_keyIndexMap.containsKey(key)) {
        final index = _keyIndexMap[key]!;
        if (!_isOutOfBound(index)) {
          _items[index] = item;
          continue;
        }
      }
      _items.add(item);
      _keys.add(key);
    }
    _trimFrontToCapacity();
    _rebuildIndexMap();
    onMemUpdate();
  }

  @override
  void clear() {
    _items.clear();
    _keys.clear();
    _keyIndexMap.clear();
    _removedFromFront = 0;
    onMemUpdate();
  }

  @override
  void deleteItemAt(int index) {
    if (_isOutOfBound(index)) return;
    _items.removeAt(index);
    _keys.removeAt(index);
    _rebuildIndexMap();
    onMemUpdate();
  }

  @override
  ItemData? get first => _items.isEmpty ? null : _items.first;

  @override
  bool get isEmpty => _items.isEmpty;

  @override
  ItemData? itemAt(int index) {
    if (_isOutOfBound(index)) return null;
    return _items[index];
  }

  @override
  ItemData? get last => _items.isEmpty ? null : _items.last;

  @override
  int get length => _items.length;

  @override
  List<ItemData> get items => List.unmodifiable(_items);

  @override
  int get nextPageToFetch {
    final knownItemsCount = _removedFromFront + _items.length;
    if (knownItemsCount == 0) return firstPageVal;
    return (knownItemsCount / perPageLimit).ceil() + firstPageVal;
  }

  @override
  int get previousPageToFetch {
    if (_removedFromFront == 0) return firstPageVal - 1;
    return (_removedFromFront / perPageLimit).ceil();
  }

  @override
  void updateItemAt(int index, ItemData item) {
    if (!_isOutOfBound(index)) {
      _items[index] = item;
      onMemUpdate();
    }
  }

  /// Returns true if index is out of bound and you should not use that index to read data from the list.
  ///
  /// Else returns false
  bool _isOutOfBound(int index) {
    return index < 0 || index >= _items.length;
  }

  @override
  void upsertItem({required ItemUniqueKey key, required ItemData item}) {
    if (_keyIndexMap.containsKey(key)) {
      _items[_keyIndexMap[key]!] = item;
      onMemUpdate();
      return;
    }
    _items.add(item);
    _keys.add(key);
    _trimFrontToCapacity();
    _rebuildIndexMap();
    onMemUpdate();
  }

  void _trimFrontToCapacity() {
    while (_items.length > maxCapacity) {
      _items.removeAt(0);
      _keys.removeAt(0);
      _removedFromFront++;
    }
  }

  void _trimBackToCapacity() {
    while (_items.length > maxCapacity) {
      _items.removeLast();
      _keys.removeLast();
    }
  }

  void _rebuildIndexMap() {
    _keyIndexMap
      ..clear()
      ..addEntries(_keys.indexed.map((entry) => MapEntry(entry.$2, entry.$1)));
  }
}
