import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_profile_service.dart';
import 'package:focushaven/widgets/focus_profile_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(FocusProfileService service) {
  return ProviderScope(
    overrides: [focusProfileServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(body: FocusProfileSheet()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the saved profile and offers to retake the quiz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'focusProfile': 'Night Owl'});
    final service = FocusProfileService();
    await tester.pump();

    await tester.pumpWidget(_app(service));
    await tester.pump();

    expect(find.text('Find your focus profile'), findsOneWidget);
    expect(
      find.text(
        'Your current profile is Night Owl. Retake the quiz anytime as your habits change.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retake quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completes, scores, and saves the four-question profile', (
    tester,
  ) async {
    final service = FocusProfileService();
    await tester.pump();

    await tester.pumpWidget(_app(service));
    await tester.pump();

    expect(find.text('Start quiz'), findsOneWidget);
    await tester.tap(find.text('Start quiz'));
    await tester.pump();

    expect(find.text('1 of 4'), findsOneWidget);
    expect(
      find.text('When does focused work feel most natural?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Early in the day'));
    await tester.pump();

    expect(find.text('2 of 4'), findsOneWidget);
    expect(find.text('Back to previous question'), findsOneWidget);
    await tester.tap(find.text('Back to previous question'));
    await tester.pump();
    expect(find.text('1 of 4'), findsOneWidget);

    await tester.tap(find.text('Early in the day'));
    await tester.pump();
    await tester.tap(find.text('Quiet and uninterrupted'));
    await tester.pump();
    await tester.tap(find.text('Removing every distraction'));
    await tester.pump();
    await tester.tap(find.text('A long, uninterrupted block'));
    await tester.pumpAndSettle();

    expect(find.text('Your focus profile'), findsOneWidget);
    expect(find.text('Deep Diver'), findsOneWidget);
    expect(
      find.text(
        'Create a quiet, distraction-free block and let yourself stay with one meaningful task.',
      ),
      findsOneWidget,
    );
    expect(service.focusType, 'Deep Diver');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('focusProfile'), 'Deep Diver');
    expect(tester.takeException(), isNull);
  });
}
