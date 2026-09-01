import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/journal_entry.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/journal_service.dart';
import 'package:focushaven/widgets/reflection_journal_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  JournalService service, {
  required JournalEntryEditor onCreateEntry,
  required SelectedJournalEntryEditor onEditEntry,
  required JournalDateLabel dateLabel,
}) {
  return ProviderScope(
    overrides: [journalServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: ReflectionJournalSheet(
          onCreateEntry: onCreateEntry,
          onEditEntry: onEditEntry,
          dateLabel: dateLabel,
        ),
      ),
    ),
  );
}

Future<JournalService> _pumpJournal(
  WidgetTester tester, {
  List<Map<String, Object?>> entries = const [],
  required JournalEntryEditor onCreateEntry,
  required SelectedJournalEntryEditor onEditEntry,
  required JournalDateLabel dateLabel,
}) async {
  SharedPreferences.setMockInitialValues({
    'journalEntries': jsonEncode(entries),
  });
  final service = JournalService();
  await tester.pump();

  await tester.pumpWidget(
    _app(
      service,
      onCreateEntry: onCreateEntry,
      onEditEntry: onEditEntry,
      dateLabel: dateLabel,
    ),
  );
  await tester.pump();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('empty journal prevents duplicate new-entry requests', (
    tester,
  ) async {
    final editorFinished = Completer<void>();
    var editorRequests = 0;

    await _pumpJournal(
      tester,
      onCreateEntry: (_) {
        editorRequests++;
        return editorFinished.future;
      },
      onEditEntry: (_, _) async {},
      dateLabel: (_) => 'Today',
    );

    expect(find.text('Reflection journal'), findsOneWidget);
    expect(find.text('Write today’s reflection'), findsOneWidget);
    expect(
      find.text('Your first reflection will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Write today’s reflection'));
    await tester.pump();
    await tester.tap(find.text('Write today’s reflection'));
    await tester.pump();

    expect(editorRequests, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    editorFinished.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows multiple same-day and previous-day reflections', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateTime.now();
    final earlierToday = today.subtract(const Duration(minutes: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final service = await _pumpJournal(
      tester,
      entries: [
        {
          'createdAt': yesterday.toIso8601String(),
          'mood': 'Grateful',
          'reflection': 'Yesterday remains in my journal.',
        },
        {
          'createdAt': earlierToday.toIso8601String(),
          'mood': 'Focused',
          'reflection': 'My earlier reflection remains separate.',
        },
        {
          'createdAt': today.toIso8601String(),
          'mood': 'Calm',
          'reflection': 'Today has its own reflection.',
        },
      ],
      onCreateEntry: (_) async {},
      onEditEntry: (_, _) async {},
      dateLabel: (date) {
        return DateUtils.isSameDay(date, today)
            ? 'Today label'
            : 'Earlier label';
      },
    );

    expect(service.entries, hasLength(3));
    expect(find.text('Write another reflection'), findsOneWidget);
    expect(find.text('Calm 1'), findsOneWidget);
    expect(find.text('Focused 1'), findsOneWidget);
    expect(find.text('Grateful 1'), findsOneWidget);
    expect(find.text('Calm • Today label'), findsOneWidget);
    expect(find.text('Today has its own reflection.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Grateful • Earlier label'),
      140,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Grateful • Earlier label'), findsOneWidget);
    expect(find.text('Yesterday remains in my journal.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit action targets exactly the selected reflection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final newer = DateTime.now();
    final selected = newer.subtract(const Duration(minutes: 1));
    JournalEntry? requestedEntry;

    await _pumpJournal(
      tester,
      entries: [
        {
          'createdAt': selected.toIso8601String(),
          'mood': 'Focused',
          'reflection': 'Edit this reflection.',
        },
        {
          'createdAt': newer.toIso8601String(),
          'mood': 'Calm',
          'reflection': 'Do not edit this reflection.',
        },
      ],
      onCreateEntry: (_) async {},
      onEditEntry: (_, entry) async {
        requestedEntry = entry;
      },
      dateLabel: (_) => 'Today',
    );

    await tester.scrollUntilVisible(
      find.text('Edit this reflection.'),
      140,
      scrollable: find.byType(Scrollable),
    );
    final selectedTile = find.byKey(ValueKey(selected));
    final selectedEditButton = find.descendant(
      of: selectedTile,
      matching: find.byTooltip('Edit reflection'),
    );
    await tester.tap(selectedEditButton);
    await tester.pumpAndSettle();

    expect(requestedEntry, isNotNull);
    expect(requestedEntry!.createdAt.isAtSameMomentAs(selected), isTrue);
    expect(requestedEntry!.reflection, 'Edit this reflection.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains create failures and restores the journal controls', (
    tester,
  ) async {
    final service = await _pumpJournal(
      tester,
      onCreateEntry: (_) async => throw StateError('editor unavailable'),
      onEditEntry: (_, _) async {},
      dateLabel: (_) => 'Today',
    );
    final createAction = find.widgetWithText(
      FilledButton,
      'Write today’s reflection',
    );

    await tester.tap(createAction);
    await tester.pumpAndSettle();

    expect(
      find.text('Reflection could not be created. Please try again.'),
      findsOneWidget,
    );
    expect(service.entries, isEmpty);
    expect(tester.widget<FilledButton>(createAction).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains edit failures and preserves the reflection', (
    tester,
  ) async {
    final createdAt = DateTime.now();
    final service = await _pumpJournal(
      tester,
      entries: [
        {
          'createdAt': createdAt.toIso8601String(),
          'mood': 'Calm',
          'reflection': 'Keep this reflection unchanged.',
        },
      ],
      onCreateEntry: (_) async {},
      onEditEntry: (_, _) async => throw StateError('editor unavailable'),
      dateLabel: (_) => 'Today',
    );
    final editAction = find.widgetWithIcon(IconButton, Icons.edit_outlined);
    final editButton = tester.widget<IconButton>(editAction);

    expect(editButton.onPressed, isNotNull);
    editButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Reflection could not be updated. Please try again.'),
      findsOneWidget,
    );
    expect(service.entries, hasLength(1));
    expect(service.entries.single.mood, 'Calm');
    expect(
      service.entries.single.reflection,
      'Keep this reflection unchanged.',
    );
    expect(tester.widget<IconButton>(editAction).onPressed, isNotNull);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Write another reflection'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
