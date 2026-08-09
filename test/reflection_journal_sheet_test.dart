import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/journal_service.dart';
import 'package:focushaven/widgets/reflection_journal_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  JournalService service, {
  required JournalEntryEditor onEditToday,
  required JournalDateLabel dateLabel,
}) {
  return ProviderScope(
    overrides: [journalServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: ReflectionJournalSheet(
          onEditToday: onEditToday,
          dateLabel: dateLabel,
        ),
      ),
    ),
  );
}

Future<JournalService> _pumpJournal(
  WidgetTester tester, {
  List<Map<String, Object?>> entries = const [],
  required JournalEntryEditor onEditToday,
  required JournalDateLabel dateLabel,
}) async {
  SharedPreferences.setMockInitialValues({
    'journalEntries': jsonEncode(entries),
  });
  final service = JournalService();
  await tester.pump();

  await tester.pumpWidget(
    _app(service, onEditToday: onEditToday, dateLabel: dateLabel),
  );
  await tester.pump();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders empty state and prevents duplicate editor requests', (
    tester,
  ) async {
    final editorFinished = Completer<void>();
    var editorRequests = 0;

    await _pumpJournal(
      tester,
      onEditToday: (_) {
        editorRequests++;
        return editorFinished.future;
      },
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

  testWidgets(
    'shows today and previous-day reflections without losing either',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final today = DateTime.now();
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
            'createdAt': today.toIso8601String(),
            'mood': 'Calm',
            'reflection': 'Today has its own reflection.',
          },
        ],
        onEditToday: (_) async {},
        dateLabel: (date) {
          return DateUtils.isSameDay(date, today)
              ? 'Today label'
              : 'Earlier label';
        },
      );

      expect(service.entries, hasLength(2));
      expect(find.text('Update today’s reflection'), findsOneWidget);
      expect(find.text('Calm 1'), findsOneWidget);
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
    },
  );
}
