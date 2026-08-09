import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/journal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<JournalService> createJournal() async {
    final journal = JournalService();
    await journal.initialized;
    return journal;
  }

  test('saves a reflection with its mood', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);

    final entry = await journal.addEntry(
      mood: 'Calm',
      reflection: 'I made space today.',
    );

    expect(entry, isNotNull);
    expect(journal.entries, hasLength(1));
    expect(journal.entries.single.mood, 'Calm');
    expect(journal.entries.single.reflection, 'I made space today.');
    expect(journal.mostCommonRecentMood, 'Calm');
  });

  test('does not save a blank reflection', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);

    final entry = await journal.addEntry(mood: 'Calm', reflection: '   ');

    expect(entry, isNull);
    expect(journal.entries, isEmpty);
  });

  test('updates an entry without changing its creation time', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);
    final original = await journal.addEntry(
      mood: 'Calm',
      reflection: 'First reflection',
    );

    final updated = await journal.updateEntry(
      createdAt: original!.createdAt,
      mood: 'Hopeful',
      reflection: 'Updated reflection',
    );

    expect(updated, isTrue);
    expect(journal.entries, hasLength(1));
    expect(journal.entries.single.createdAt, original.createdAt);
    expect(journal.entries.single.mood, 'Hopeful');
    expect(journal.entries.single.reflection, 'Updated reflection');
  });

  test(
    'adding an entry preserves a previous-day reflection during startup',
    () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'journalEntries': jsonEncode([
          {
            'createdAt': yesterday.toIso8601String(),
            'mood': 'Grateful',
            'reflection': 'Yesterday remains part of my journal.',
          },
        ]),
      });

      final journal = JournalService();
      addTearDown(journal.dispose);

      // Save immediately to cover the startup-loading race that previously
      // allowed an older journal history to be overwritten.
      await journal.addEntry(
        mood: 'Focused',
        reflection: 'Today is a new entry.',
      );

      expect(journal.entries, hasLength(2));
      expect(
        journal.entries.map((entry) => entry.reflection),
        containsAll([
          'Yesterday remains part of my journal.',
          'Today is a new entry.',
        ]),
      );

      final preferences = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(preferences.getString('journalEntries')!) as List;
      expect(saved, hasLength(2));
    },
  );

  test(
    'adds multiple reflections on the same day without replacing them',
    () async {
      final journal = await createJournal();
      addTearDown(journal.dispose);

      final first = await journal.addEntry(
        mood: 'Calm',
        reflection: 'My first reflection today.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final second = await journal.addEntry(
        mood: 'Focused',
        reflection: 'My second reflection today.',
      );

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(journal.entries, hasLength(2));
      expect(
        journal.entries.map((entry) => entry.reflection),
        containsAll([
          'My first reflection today.',
          'My second reflection today.',
        ]),
      );
      expect(journal.entries.first.reflection, 'My second reflection today.');

      final preferences = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(preferences.getString('journalEntries')!) as List;
      expect(saved, hasLength(2));
    },
  );

  test('updates only the selected same-day reflection', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);

    final first = await journal.addEntry(
      mood: 'Calm',
      reflection: 'Keep this entry identity.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final second = await journal.addEntry(
      mood: 'Focused',
      reflection: 'Leave this reflection unchanged.',
    );

    final updated = await journal.updateEntry(
      createdAt: first!.createdAt,
      mood: 'Grateful',
      reflection: 'Updated only the selected reflection.',
    );

    expect(updated, isTrue);
    expect(journal.entries, hasLength(2));
    final editedEntry = journal.entries.singleWhere(
      (entry) => entry.createdAt.isAtSameMomentAs(first.createdAt),
    );
    final untouchedEntry = journal.entries.singleWhere(
      (entry) => entry.createdAt.isAtSameMomentAs(second!.createdAt),
    );
    expect(editedEntry.mood, 'Grateful');
    expect(editedEntry.reflection, 'Updated only the selected reflection.');
    expect(untouchedEntry.mood, 'Focused');
    expect(untouchedEntry.reflection, 'Leave this reflection unchanged.');
  });

  test(
    'rejects invalid journal entry operations without changing history',
    () async {
      final journal = await createJournal();
      addTearDown(journal.dispose);
      final saved = await journal.addEntry(
        mood: 'Calm',
        reflection: 'This valid reflection stays saved.',
      );

      final blankEntry = await journal.addEntry(
        mood: 'Calm',
        reflection: '   ',
      );
      final missingUpdate = await journal.updateEntry(
        createdAt: saved!.createdAt.subtract(const Duration(days: 30)),
        mood: 'Focused',
        reflection: 'This target does not exist.',
      );

      expect(blankEntry, isNull);
      expect(missingUpdate, isFalse);
      expect(journal.entries, hasLength(1));
      expect(
        journal.entries.single.reflection,
        'This valid reflection stays saved.',
      );
    },
  );

  test('clearing local data removes saved journal entries', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);
    await journal.addEntry(mood: 'Calm', reflection: 'A private thought');

    await journal.clearLocalData();

    expect(journal.entries, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('journalEntries'), isFalse);
  });

  test('loads saved reflections on launch', () async {
    final savedAt = DateTime.now().subtract(const Duration(minutes: 1));
    SharedPreferences.setMockInitialValues({
      'journalEntries': jsonEncode([
        {
          'createdAt': savedAt.toIso8601String(),
          'mood': 'Calm',
          'reflection': 'I made room for a quiet moment.',
        },
      ]),
    });

    final journal = await createJournal();
    addTearDown(journal.dispose);

    expect(
      journal.entries.single.reflection,
      'I made room for a quiet moment.',
    );
    expect(journal.mostCommonRecentMood, 'Calm');
  });

  test('recent moods include the full oldest local calendar day', () async {
    final now = DateTime.now().toLocal();
    final oldestDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    SharedPreferences.setMockInitialValues({
      'journalEntries': jsonEncode([
        {
          'createdAt': oldestDay.toIso8601String(),
          'mood': 'Included',
          'reflection': 'The oldest calendar day still counts.',
        },
        {
          'createdAt': oldestDay
              .subtract(const Duration(microseconds: 1))
              .toIso8601String(),
          'mood': 'Excluded',
          'reflection': 'This falls before the seven-day window.',
        },
      ]),
    });

    final journal = await createJournal();
    addTearDown(journal.dispose);

    expect(journal.recentMoodCounts, {'Included': 1});
    expect(journal.mostCommonRecentMood, 'Included');
  });

  test(
    'preserves and normalizes valid records beside corrupted data',
    () async {
      final createdAt = DateTime(2026, 8, 8, 12);
      SharedPreferences.setMockInitialValues({
        'journalEntries': jsonEncode([
          {
            'createdAt': createdAt.toIso8601String(),
            'mood': '  Calm  ',
            'reflection': '  This valid reflection remains.  ',
          },
          'not a journal record',
          {
            'createdAt': 'not-a-date',
            'mood': 'Focused',
            'reflection': 'Invalid timestamp',
          },
          {
            'createdAt': createdAt.toIso8601String(),
            'mood': 'Duplicate',
            'reflection': 'Duplicate identity',
          },
          {
            'createdAt': DateTime(2026, 8, 7).toIso8601String(),
            'mood': '   ',
            'reflection': 'Blank mood',
          },
        ]),
      });

      final journal = await createJournal();
      addTearDown(journal.dispose);

      expect(journal.entries, hasLength(1));
      expect(journal.entries.single.createdAt, createdAt);
      expect(journal.entries.single.mood, 'Calm');
      expect(
        journal.entries.single.reflection,
        'This valid reflection remains.',
      );

      final preferences = await SharedPreferences.getInstance();
      final repaired =
          jsonDecode(preferences.getString('journalEntries')!) as List;
      expect(repaired, hasLength(1));
      expect((repaired.single as Map)['mood'], 'Calm');
      expect(
        (repaired.single as Map)['reflection'],
        'This valid reflection remains.',
      );
    },
  );

  test('removes malformed and incorrectly shaped journal storage', () async {
    SharedPreferences.setMockInitialValues({
      'journalEntries': '{malformed json',
    });
    final malformedJournal = await createJournal();
    addTearDown(malformedJournal.dispose);
    var preferences = await SharedPreferences.getInstance();

    expect(malformedJournal.entries, isEmpty);
    expect(preferences.containsKey('journalEntries'), isFalse);

    SharedPreferences.setMockInitialValues({
      'journalEntries': jsonEncode({'entry': 'not a list'}),
    });
    final wrongShapeJournal = await createJournal();
    addTearDown(wrongShapeJournal.dispose);
    preferences = await SharedPreferences.getInstance();

    expect(wrongShapeJournal.entries, isEmpty);
    expect(preferences.containsKey('journalEntries'), isFalse);
  });

  test('an unchanged update does not publish another revision', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);
    final entry = await journal.addEntry(
      mood: 'Calm',
      reflection: 'Keep this reflection unchanged.',
    );
    final revision = journal.journalRevision;
    var notifications = 0;
    journal.addListener(() => notifications++);

    final updated = await journal.updateEntry(
      createdAt: entry!.createdAt,
      mood: '  Calm  ',
      reflection: '  Keep this reflection unchanged.  ',
    );

    expect(updated, isTrue);
    expect(journal.journalRevision, revision);
    expect(notifications, 0);
    expect(journal.entries.single, same(entry));
  });

  test('initialization and mutations are safe after disposal', () async {
    SharedPreferences.setMockInitialValues({
      'journalEntries': jsonEncode([
        {
          'createdAt': DateTime(2026, 8, 8).toIso8601String(),
          'mood': 'Calm',
          'reflection': 'Do not publish after disposal.',
        },
      ]),
    });
    final journal = JournalService();
    journal.dispose();

    await journal.initialized;
    final added = await journal.addEntry(
      mood: 'Focused',
      reflection: 'This should not be added.',
    );
    final updated = await journal.updateEntry(
      createdAt: DateTime(2026, 8, 8),
      mood: 'Focused',
      reflection: 'This should not be updated.',
    );
    await journal.clearLocalData();

    expect(added, isNull);
    expect(updated, isFalse);
    expect(journal.entries, isEmpty);
  });
}
