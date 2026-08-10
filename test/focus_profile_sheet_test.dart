import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_profile_service.dart';
import 'package:focushaven/widgets/focus_profile_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(FocusProfileService service, {FocusProfileSaver? saveFocusType}) {
  return ProviderScope(
    overrides: [focusProfileServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: FocusProfileSheet(saveFocusType: saveFocusType)),
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

    expect(find.byTooltip('Back to account settings'), findsOneWidget);
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

    expect(find.byTooltip('Back to account settings'), findsOneWidget);
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

    expect(find.byTooltip('Back to account settings'), findsOneWidget);
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

  testWidgets('blocks duplicate answer selections', (tester) async {
    final service = FocusProfileService();
    await tester.pump();

    await tester.pumpWidget(_app(service));
    await tester.pump();
    await tester.tap(find.text('Start quiz'));
    await tester.pump();

    final firstChoice = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Early in the day'),
    );
    firstChoice.onPressed!.call();
    firstChoice.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('2 of 4'), findsOneWidget);
    expect(find.text('Which environment helps you settle in?'), findsOneWidget);
    expect(find.text('When you feel stuck, what helps most?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains save failures and restores the final choices', (
    tester,
  ) async {
    final service = FocusProfileService();
    await tester.pump();
    var saveCalls = 0;

    await tester.pumpWidget(
      _app(
        service,
        saveFocusType: (focusType) async {
          saveCalls += 1;
          throw StateError('profile storage unavailable');
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Start quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Early in the day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiet and uninterrupted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Removing every distraction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A long, uninterrupted block'));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(find.text('4 of 4'), findsOneWidget);
    expect(
      find.text('Your focus profile could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'A long, uninterrupted block'),
          )
          .onPressed,
      isNotNull,
    );
    expect(service.focusType, isNull);
    expect(tester.takeException(), isNull);
  });
}
