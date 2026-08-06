import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/journal_entry.dart';

class JournalService extends ChangeNotifier {
  static const _storageKey = 'journalEntries';
  static const _prompts = [
    'What is one thing you are grateful for today?',
    'What helped you feel focused today?',
    'What would make tomorrow feel a little lighter?',
    'What small win are you proud of today?',
    'What do you want to give yourself permission to release?',
    'Who or what brought you a moment of calm today?',
    'What is one kind thing you can do for yourself next?',
  ];
  List<JournalEntry> _entries = [];

  List<JournalEntry> get entries => List.unmodifiable(_entries.reversed);
  Map<String, int> get recentMoodCounts {
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final counts = <String, int>{};
    for (final entry in _entries) {
      if (entry.createdAt.isAfter(cutoff)) {
        counts.update(entry.mood, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  String? get mostCommonRecentMood {
    final counts = recentMoodCounts;
    if (counts.isEmpty) return null;
    return counts.entries.reduce((first, next) => first.value >= next.value ? first : next).key;
  }
  String get dailyPrompt {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return _prompts[dayOfYear % _prompts.length];
  }
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

  Future<void> clearLocalData() async {
    _entries = [];
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
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
