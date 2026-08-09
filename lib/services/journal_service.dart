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
  int _journalRevision = 0;
  late final Future<void> _loadFuture;

  List<JournalEntry> get entries => List.unmodifiable(_entries.reversed);

  /// Changes only when journal entries are loaded, added, updated, or cleared.
  int get journalRevision => _journalRevision;

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
    return counts.entries
        .reduce((first, next) => first.value >= next.value ? first : next)
        .key;
  }

  String get dailyPrompt {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return _prompts[dayOfYear % _prompts.length];
  }

  JournalService() {
    _loadFuture = _load();
  }

  /// Appends a new reflection, even when other reflections already exist for
  /// the same local calendar day.
  Future<JournalEntry?> addEntry({
    required String mood,
    required String reflection,
  }) async {
    final cleanMood = mood.trim();
    final cleanReflection = reflection.trim();
    if (cleanMood.isEmpty || cleanReflection.isEmpty) return null;

    await _loadFuture;

    final entry = JournalEntry(
      createdAt: _nextCreatedAt(),
      mood: cleanMood,
      reflection: cleanReflection,
    );
    _entries.add(entry);
    await _save();
    _notifyJournalChanged();
    return entry;
  }

  /// Updates exactly one persisted reflection without changing its identity or
  /// original creation time.
  Future<bool> updateEntry({
    required DateTime createdAt,
    required String mood,
    required String reflection,
  }) async {
    final cleanMood = mood.trim();
    final cleanReflection = reflection.trim();
    if (cleanMood.isEmpty || cleanReflection.isEmpty) return false;

    await _loadFuture;

    final index = _entries.indexWhere(
      (entry) => entry.createdAt.isAtSameMomentAs(createdAt),
    );
    if (index == -1) return false;

    _entries[index] = JournalEntry(
      createdAt: _entries[index].createdAt,
      mood: cleanMood,
      reflection: cleanReflection,
    );
    await _save();
    _notifyJournalChanged();
    return true;
  }

  Future<void> clearLocalData() async {
    await _loadFuture;
    _entries = [];
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    _notifyJournalChanged();
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
            .map(
              (item) => JournalEntry.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        _notifyJournalChanged();
      }
    } on FormatException {
      _entries = [];
    } on TypeError {
      _entries = [];
    }
  }

  void _notifyJournalChanged() {
    _journalRevision++;
    notifyListeners();
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }

  DateTime _nextCreatedAt() {
    var candidate = DateTime.now();
    while (_entries.any(
      (entry) => entry.createdAt.isAtSameMomentAs(candidate),
    )) {
      candidate = candidate.add(const Duration(microseconds: 1));
    }
    return candidate;
  }
}
