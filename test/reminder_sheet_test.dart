import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/notification_service.dart';
import 'package:focushaven/services/reminder_service.dart';
import 'package:focushaven/widgets/reminder_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReminderNotifications implements ReminderNotificationClient {
  final List<TimeOfDay> scheduledTimes = [];
  final List<Set<int>> scheduledWeekdays = [];
  var cancelCalls = 0;

  @override
  Future<void> cancelDailyReminder() async {
    cancelCalls += 1;
  }

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> scheduleDailyReminder(TimeOfDay time, Set<int> weekdays) async {
    scheduledTimes.add(time);
    scheduledWeekdays.add(Set<int>.from(weekdays));
    return true;
  }
}

ReminderService _createService(_FakeReminderNotifications notifications) =>
    ReminderService(notificationService: notifications);

Widget _app(ReminderService service) {
  return ProviderScope(
    overrides: [reminderServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(body: ReminderSheet()),
    ),
  );
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders saved reminder time and selected weekdays', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'dailyReminderEnabled': true,
      'dailyReminderHour': 18,
      'dailyReminderMinute': 30,
      'dailyReminderWeekdays': ['1', '3', '5'],
    });
    final notifications = _FakeReminderNotifications();
    final service = _createService(notifications);
    await tester.pump();

    await tester.pumpWidget(_app(service));
    await _pumpUi(tester);

    expect(find.text('Focus time is scheduled'), findsOneWidget);
    expect(find.text('6:30 PM • Mon, Wed, Fri'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Mon'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Tue'))
          .selected,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning off a reminder cancels the schedule', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dailyReminderEnabled': true,
      'dailyReminderHour': 8,
      'dailyReminderMinute': 15,
    });
    final notifications = _FakeReminderNotifications();
    final service = _createService(notifications);
    await tester.pump();

    await tester.pumpWidget(_app(service));
    await _pumpUi(tester);
    await tester.tap(find.byType(Switch));
    await _pumpUi(tester);

    expect(service.isEnabled, isFalse);
    expect(notifications.cancelCalls, 1);
    expect(find.text('No focus time scheduled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning on a reminder schedules the selected weekdays', (
    tester,
  ) async {
    final notifications = _FakeReminderNotifications();
    final service = _createService(notifications);
    await tester.pump();

    await tester.pumpWidget(_app(service));
    await _pumpUi(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await _pumpUi(tester);

    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await _pumpUi(tester);

    expect(service.isEnabled, isTrue);
    expect(service.time, const TimeOfDay(hour: 9, minute: 0));
    expect(service.weekdays, {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    });
    expect(notifications.scheduledTimes, [const TimeOfDay(hour: 9, minute: 0)]);
    expect(notifications.scheduledWeekdays.single, service.weekdays);
    expect(find.text('Focus time is scheduled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
