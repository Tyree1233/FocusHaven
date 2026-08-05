import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusQueueItem {
  const FocusQueueItem({required this.id, required this.title, this.isComplete = false});

  final String id;
  final String title;
  final bool isComplete;

  FocusQueueItem copyWith({bool? isComplete}) =>
      FocusQueueItem(id: id, title: title, isComplete: isComplete ?? this.isComplete);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'isComplete': isComplete};

  factory FocusQueueItem.fromJson(Map<String, dynamic> json) => FocusQueueItem(
        id: json['id'] as String,
        title: json['title'] as String,
        isComplete: json['isComplete'] == true,
      );
}

class FocusQueueService extends ChangeNotifier {
  static const _storageKey = 'focusQueue';
  List<FocusQueueItem> _items = [];

  FocusQueueService() {
    _load();
  }

  List<FocusQueueItem> get items => List.unmodifiable(_items);
  int get remainingCount => _items.where((item) => !item.isComplete).length;

  Future<void> add(String title) async {
    final cleaned = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return;
    final limited = cleaned.length > 100 ? cleaned.substring(0, 100) : cleaned;
    _items.add(FocusQueueItem(id: DateTime.now().microsecondsSinceEpoch.toString(), title: limited));
    await _save();
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    _items = _items.map((item) => item.id == id ? item.copyWith(isComplete: !item.isComplete) : item).toList();
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == null) return;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is List) {
        _items = decoded.whereType<Map>().map((item) => FocusQueueItem.fromJson(Map<String, dynamic>.from(item))).toList();
        notifyListeners();
      }
    } on FormatException {
      _items = [];
    } on TypeError {
      _items = [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_items.map((item) => item.toJson()).toList()));
  }
}
