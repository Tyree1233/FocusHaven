import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusQueueItem {
  const FocusQueueItem({
    required this.id,
    required this.title,
    this.isComplete = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final bool isComplete;
  final DateTime? completedAt;

  FocusQueueItem copyWith({
    String? title,
    bool? isComplete,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => FocusQueueItem(
    id: id,
    title: title ?? this.title,
    isComplete: isComplete ?? this.isComplete,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isComplete': isComplete,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  factory FocusQueueItem.fromJson(Map<String, dynamic> json) => FocusQueueItem(
    id: json['id'] as String,
    title: json['title'] as String,
    isComplete: json['isComplete'] == true,
    completedAt: json['completedAt'] is String
        ? DateTime.tryParse(json['completedAt'] as String)
        : null,
  );
}

class FocusQueueService extends ChangeNotifier {
  static const _storageKey = 'focusQueue';
  List<FocusQueueItem> _items = [];
  int _queueRevision = 0;
  late final Future<void> _loadFuture;

  FocusQueueService() {
    _loadFuture = _load();
  }

  List<FocusQueueItem> get items =>
      List.unmodifiable(_items.where((item) => !item.isComplete));
  List<FocusQueueItem> get completedItems => List.unmodifiable(
    _items.where((item) => item.isComplete).toList().reversed,
  );
  int get remainingCount => items.length;
  int get queueRevision => _queueRevision;
  int get completedToday => _items.where((item) {
    final completedAt = item.completedAt;
    if (completedAt == null) return false;
    final localCompletedAt = completedAt.toLocal();
    final localNow = DateTime.now().toLocal();
    return localCompletedAt.year == localNow.year &&
        localCompletedAt.month == localNow.month &&
        localCompletedAt.day == localNow.day;
  }).length;

  Future<void> add(String title) async {
    final limited = _cleanTitle(title);
    if (limited == null) return;
    await _loadFuture;

    _items.add(FocusQueueItem(id: _nextItemId(), title: limited));
    await _save();
    _notifyQueueChanged();
  }

  Future<void> rename(String id, String title) async {
    final limited = _cleanTitle(title);
    if (limited == null) return;
    await _loadFuture;

    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1 || _items[index].title == limited) return;

    _items[index] = _items[index].copyWith(title: limited);
    await _save();
    _notifyQueueChanged();
  }

  Future<void> toggle(String id) async {
    await _loadFuture;

    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final item = _items[index];
    _items[index] = item.copyWith(
      isComplete: !item.isComplete,
      completedAt: item.isComplete ? null : DateTime.now(),
      clearCompletedAt: item.isComplete,
    );
    await _save();
    _notifyQueueChanged();
  }

  Future<void> remove(String id) async {
    await _loadFuture;

    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    _items.removeAt(index);
    await _save();
    _notifyQueueChanged();
  }

  Future<void> clearLocalData() async {
    await _loadFuture;

    _items = [];
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    _notifyQueueChanged();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == null) return;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is List) {
        final loadedItems = <FocusQueueItem>[];
        final loadedIds = <String>{};
        for (final value in decoded) {
          final item = _decodeQueueItem(value);
          if (item != null && loadedIds.add(item.id)) {
            loadedItems.add(item);
          }
        }
        _items = loadedItems;
        _notifyQueueChanged();
      }
    } on FormatException {
      _items = [];
    }
  }

  FocusQueueItem? _decodeQueueItem(Object? value) {
    if (value is! Map) return null;

    try {
      final item = FocusQueueItem.fromJson(Map<String, dynamic>.from(value));
      final id = item.id.trim();
      final title = _cleanTitle(item.title);
      if (id.isEmpty || title == null) return null;

      return FocusQueueItem(
        id: id,
        title: title,
        isComplete: item.isComplete,
        completedAt: item.isComplete ? item.completedAt : null,
      );
    } on TypeError {
      return null;
    }
  }

  void _notifyQueueChanged() {
    _queueRevision++;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  String _nextItemId() {
    var candidate = DateTime.now().microsecondsSinceEpoch;
    while (_items.any((item) => item.id == candidate.toString())) {
      candidate++;
    }
    return candidate.toString();
  }
}

String? _cleanTitle(String title) {
  final cleaned = title.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return null;
  return cleaned.length > 100 ? cleaned.substring(0, 100) : cleaned;
}
