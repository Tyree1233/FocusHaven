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
  bool _isDisposed = false;

  JournalService() {
    initialized = _load();
  }

  late final Future<void> initialized;

  List<JournalEntry> get entries => List.unmodifiable(_entries.reversed);

  /// Changes only when journal entries are loaded, added, updated, or cleared.
  int get journalRevision => _journalRevision;

  Map<String, int> get recentMoodCounts {
    final now = DateTime.now().toLocal();
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final counts = <String, int>{};
    for (final entry in _entries) {
      if (!entry.createdAt.toLocal().isBefore(cutoff)) {
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

  /// Appends a new reflection, even when other reflections already exist for
  /// the same local calendar day.
  Future<JournalEntry?> addEntry({
    required String mood,
    required String reflection,
  }) async {
    final cleanMood = mood.trim();
    final cleanReflection = reflection.trim();
    if (cleanMood.isEmpty || cleanReflection.isEmpty) return null;

    await initialized;
    if (_isDisposed) return null;

    final entry = JournalEntry(
      createdAt: _nextCreatedAt(),
      mood: cleanMood,
      reflection: cleanReflection,
    );
    final updatedEntries = [..._entries, entry];
    await _saveEntries(updatedEntries);
    if (_isDisposed) return null;

    _entries = updatedEntries;
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

    await initialized;
    if (_isDisposed) return false;

    final index = _entries.indexWhere(
      (entry) => entry.createdAt.isAtSameMomentAs(createdAt),
    );
    if (index == -1) return false;
    final existingEntry = _entries[index];
    if (existingEntry.mood == cleanMood &&
        existingEntry.reflection == cleanReflection) {
      return true;
    }

    final updatedEntries = List<JournalEntry>.of(_entries);
    updatedEntries[index] = JournalEntry(
      createdAt: existingEntry.createdAt,
      mood: cleanMood,
      reflection: cleanReflection,
    );
    await _saveEntries(updatedEntries);
    if (_isDisposed) return false;

    _entries = updatedEntries;
    _notifyJournalChanged();
    return true;
  }

  Future<void> clearLocalData() async {
    await initialized;
    if (_isDisposed) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    if (_isDisposed) return;

    final changed = _entries.isNotEmpty;
    _entries = [];
    if (changed) _notifyJournalChanged();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_isDisposed) return;

      final savedValue = preferences.get(_storageKey);
      if (savedValue == null) return;
      if (savedValue is! String) {
        await preferences.remove(_storageKey);
        return;
      }
      final saved = savedValue;
      final decoded = jsonDecode(saved);
      if (decoded is! List) {
        await preferences.remove(_storageKey);
        return;
      }

      final loadedEntries = <JournalEntry>[];
      final loadedTimestamps = <int>{};
      for (final value in decoded) {
        final entry = _decodeJournalEntry(value);
        if (entry != null &&
            loadedTimestamps.add(entry.createdAt.microsecondsSinceEpoch)) {
          loadedEntries.add(entry);
        }
      }
      if (_isDisposed) return;

      if (loadedEntries.isEmpty) {
        await preferences.remove(_storageKey);
      } else {
        final normalizedStorage = jsonEncode(
          loadedEntries.map((entry) => entry.toJson()).toList(),
        );
        if (normalizedStorage != saved) {
          await preferences.setString(_storageKey, normalizedStorage);
        }
      }
      if (_isDisposed) return;

      _entries = loadedEntries;
      _notifyJournalChanged();
    } on FormatException {
      await _removeCorruptedStorage();
    } on TypeError {
      await _removeCorruptedStorage();
    } catch (error) {
      debugPrint('Journal entries could not be loaded: $error');
    }
  }

  JournalEntry? _decodeJournalEntry(Object? value) {
    if (value is! Map) return null;

    try {
      final entry = JournalEntry.fromJson(Map<String, dynamic>.from(value));
      final mood = entry.mood.trim();
      final reflection = entry.reflection.trim();
      if (mood.isEmpty || reflection.isEmpty) return null;

      return JournalEntry(
        createdAt: entry.createdAt,
        mood: mood,
        reflection: reflection,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> _removeCorruptedStorage() async {
    if (_isDisposed) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_storageKey);
    } catch (error) {
      debugPrint('Corrupted journal storage could not be removed: $error');
    }
  }

  void _notifyJournalChanged() {
    if (_isDisposed) return;
    _journalRevision++;
    notifyListeners();
  }

  Future<void> _saveEntries(List<JournalEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
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

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
