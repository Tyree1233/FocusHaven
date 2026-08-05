import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/journal_entry.dart';

class JournalService extends ChangeNotifier {
  static const _storageKey = 'journalEntries';
  List<JournalEntry> _entries = [];

  List<JournalEntry> get entries => List.unmodifiable(_entries.reversed);
  JournalEntry? get todayEntry {
    for (final entry in _entries.reversed) {
      if (_isToday(entry.createdAt)) return entry;
    }
    return null;
  }

  JournalService() {
    _load();
  }

  Future<void> saveToday({required String mood, required String reflection}) async {
    final cleanReflection = reflection.trim();
    if (cleanReflection.isEmpty) return;

    final now = DateTime.now();
    final entry = JournalEntry(
      createdAt: now,
      mood: mood,
      reflection: cleanReflection,
    );
    _entries = _entries.where((item) => !_isToday(item.createdAt)).toList()..add(entry);
    await _save();
    notifyListeners();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_storageKey);
    if (saved == null) return;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is List) {
        _entries = decoded
            .whereType<Map>()
            .map((item) => JournalEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        notifyListeners();
      }
    } on FormatException {
      _entries = [];
    } on TypeError {
      _entries = [];
    }
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}
