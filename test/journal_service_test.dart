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
    await Future<void>.delayed(Duration.zero);
    return journal;
  }

  test('saves a reflection with its mood', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);

    await journal.saveToday(mood: 'Calm', reflection: 'I made space today.');

    expect(journal.entries, hasLength(1));
    expect(journal.todayEntry!.mood, 'Calm');
    expect(journal.todayEntry!.reflection, 'I made space today.');
    expect(journal.mostCommonRecentMood, 'Calm');
  });

  test('does not save a blank reflection', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);

    await journal.saveToday(mood: 'Calm', reflection: '   ');

    expect(journal.entries, isEmpty);
  });

  test('replaces the existing entry for today', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);
    await journal.saveToday(mood: 'Calm', reflection: 'First reflection');

    await journal.saveToday(mood: 'Hopeful', reflection: 'Updated reflection');

    expect(journal.entries, hasLength(1));
    expect(journal.todayEntry!.mood, 'Hopeful');
    expect(journal.todayEntry!.reflection, 'Updated reflection');
  });

  test('clearing local data removes saved journal entries', () async {
    final journal = await createJournal();
    addTearDown(journal.dispose);
    await journal.saveToday(
      mood: 'Calm',
      reflection: 'A private thought',
    );

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

    expect(journal.entries.single.reflection, 'I made room for a quiet moment.');
    expect(journal.mostCommonRecentMood, 'Calm');
  });
}
