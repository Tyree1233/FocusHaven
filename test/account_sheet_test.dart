import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/auth_service.dart';
import 'package:focushaven/widgets/account_sheet.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({required this.signedIn, this.name = 'Guest', this.error});

  final bool signedIn;
  final String name;
  final String? error;
  var signInCalls = 0;
  var signOutCalls = 0;

  @override
  bool get isSignedIn => signedIn;

  @override
  String get displayName => name;

  @override
  String? get signInError => error;

  @override
  Future<UserCredential?> signInWithGoogle() async {
    signInCalls += 1;
    return null;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

class _ActionLog {
  var deleteCloudCalls = 0;
  var deleteLocalCalls = 0;
  var openProCalls = 0;
  var openProfileCalls = 0;
  var openAppearanceCalls = 0;
  var openPrivacyCalls = 0;

  Future<void> deleteCloud() async {
    deleteCloudCalls += 1;
  }

  Future<void> deleteLocal() async {
    deleteLocalCalls += 1;
  }

  Future<void> openPro() async {
    openProCalls += 1;
  }

  Future<void> openProfile() async {
    openProfileCalls += 1;
  }

  Future<void> openAppearance() async {
    openAppearanceCalls += 1;
  }

  Future<void> openPrivacy() async {
    openPrivacyCalls += 1;
  }
}

Widget _app(_FakeAuthService auth, _ActionLog actions) {
  return ProviderScope(
    overrides: [authServiceProvider.overrideWith((ref) => auth)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: AccountSheet(
          deleteCloudBackup: actions.deleteCloud,
          deleteLocalData: actions.deleteLocal,
          openPro: actions.openPro,
          openFocusProfile: actions.openProfile,
          openAppearance: actions.openAppearance,
          openPrivacyPolicy: actions.openPrivacy,
        ),
      ),
    ),
  );
}

void _invokeTextButton(WidgetTester tester, String label) {
  final button = tester.widget<TextButton>(
    find.widgetWithText(TextButton, label),
  );
  button.onPressed!.call();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows signed-out privacy state and dispatches account actions', (
    tester,
  ) async {
    final auth = _FakeAuthService(
      signedIn: false,
      error: 'Choose a Google account to continue.',
    );
    final actions = _ActionLog();

    await tester.pumpWidget(_app(auth, actions));
    await tester.pumpAndSettle();

    expect(find.text('Your FocusHaven account'), findsOneWidget);
    expect(
      find.text('Sign in to protect your focus history and use cloud backup.'),
      findsOneWidget,
    );
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Delete cloud backup'), findsNothing);

    final signInButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign in with Google'),
    );
    signInButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(find.text('Choose a Google account to continue.'), findsOneWidget);

    _invokeTextButton(tester, 'Delete local data');
    _invokeTextButton(tester, 'FocusHaven Pro');
    _invokeTextButton(tester, 'Discover your focus profile');
    _invokeTextButton(tester, 'Appearance');
    _invokeTextButton(tester, 'Privacy Policy');
    await tester.pump();

    expect(actions.deleteLocalCalls, 1);
    expect(actions.openProCalls, 1);
    expect(actions.openProfileCalls, 1);
    expect(actions.openAppearanceCalls, 1);
    expect(actions.openPrivacyCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows signed-in account controls and dispatches secure actions',
    (tester) async {
      final auth = _FakeAuthService(signedIn: true, name: 'Tyree Jones');
      final actions = _ActionLog();

      await tester.pumpWidget(_app(auth, actions));
      await tester.pumpAndSettle();

      expect(find.text('Signed in as Tyree Jones'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
      expect(find.text('Delete cloud backup'), findsOneWidget);

      final signOutButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Sign out'),
      );
      signOutButton.onPressed!.call();
      _invokeTextButton(tester, 'Delete cloud backup');
      await tester.pump();

      expect(auth.signOutCalls, 1);
      expect(actions.deleteCloudCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
