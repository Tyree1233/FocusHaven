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
  }) => FocusQueueItem(
    id: id,
    title: title ?? this.title,
    isComplete: isComplete ?? this.isComplete,
    completedAt: completedAt,
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

  FocusQueueService() {
    _load();
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
    final now = DateTime.now();
    return completedAt.year == now.year &&
        completedAt.month == now.month &&
        completedAt.day == now.day;
  }).length;

  Future<void> add(String title) async {
    final limited = _cleanTitle(title);
    if (limited == null) return;
    _items.add(
      FocusQueueItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: limited,
      ),
    );
    await _save();
    _notifyQueueChanged();
  }

  Future<void> rename(String id, String title) async {
    final limited = _cleanTitle(title);
    if (limited == null) return;
    _items = _items
        .map((item) => item.id == id ? item.copyWith(title: limited) : item)
        .toList();
    await _save();
    _notifyQueueChanged();
  }

  Future<void> toggle(String id) async {
    _items = _items
        .map(
          (item) => item.id == id
              ? item.copyWith(
                  isComplete: !item.isComplete,
                  completedAt: item.isComplete ? null : DateTime.now(),
                )
              : item,
        )
        .toList();
    await _save();
    _notifyQueueChanged();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _save();
    _notifyQueueChanged();
  }

  Future<void> clearLocalData() async {
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
        _items = decoded
            .whereType<Map>()
            .map(
              (item) =>
                  FocusQueueItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        _notifyQueueChanged();
      }
    } on FormatException {
      _items = [];
    } on TypeError {
      _items = [];
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
}

String? _cleanTitle(String title) {
  final cleaned = title.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return null;
  return cleaned.length > 100 ? cleaned.substring(0, 100) : cleaned;
}
