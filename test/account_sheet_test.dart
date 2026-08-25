import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/auth_service.dart';
import 'package:focushaven/widgets/account_sheet.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    required this.signedIn,
    this.name = 'Guest',
    this.error,
    this.appleSupported = false,
  });

  final bool signedIn;
  final String name;
  final String? error;
  final bool appleSupported;
  var signInCalls = 0;
  var appleSignInCalls = 0;
  var signOutCalls = 0;
  Completer<UserCredential?>? pendingSignIn;
  Completer<void>? pendingSignOut;

  @override
  bool get isSignedIn => signedIn;

  @override
  String get displayName => name;

  @override
  String? get signInError => error;

  @override
  bool get supportsAppleSignIn => appleSupported;

  @override
  Future<UserCredential?> signInWithGoogle() async {
    signInCalls += 1;
    final pending = pendingSignIn;
    if (pending != null) {
      return pending.future;
    }
    return null;
  }

  @override
  Future<UserCredential?> signInWithApple() async {
    appleSignInCalls += 1;
    final pending = pendingSignIn;
    if (pending != null) return pending.future;
    return null;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    final pending = pendingSignOut;
    if (pending != null) {
      await pending.future;
    }
  }
}

class _ActionLog {
  var deleteAccountCalls = 0;
  var deleteCloudCalls = 0;
  var deleteLocalCalls = 0;
  var openProCalls = 0;
  var openProfileCalls = 0;
  var openAppearanceCalls = 0;
  var openPrivacyCalls = 0;
  Completer<void>? pendingDeleteLocal;

  Future<void> deleteAccount() async {
    deleteAccountCalls += 1;
  }

  Future<void> deleteCloud() async {
    deleteCloudCalls += 1;
  }

  Future<void> deleteLocal() async {
    deleteLocalCalls += 1;
    final pending = pendingDeleteLocal;
    if (pending != null) {
      await pending.future;
    }
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
          deleteAccount: actions.deleteAccount,
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
    expect(find.byTooltip('Close account settings'), findsOneWidget);
    expect(
      find.text('Sign in to protect your focus history and use cloud backup.'),
      findsOneWidget,
    );
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Delete cloud backup'), findsNothing);
    expect(find.text('Delete account'), findsNothing);

    final signInButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign in with Google'),
    );
    signInButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(find.text('Choose a Google account to continue.'), findsOneWidget);

    _invokeTextButton(tester, 'Delete local data');
    await tester.pumpAndSettle();
    _invokeTextButton(tester, 'FocusHaven Pro');
    await tester.pumpAndSettle();
    _invokeTextButton(tester, 'Discover your focus profile');
    await tester.pumpAndSettle();
    _invokeTextButton(tester, 'Appearance');
    await tester.pumpAndSettle();
    _invokeTextButton(tester, 'Privacy Policy');
    await tester.pumpAndSettle();

    expect(actions.deleteLocalCalls, 1);
    expect(actions.openProCalls, 1);
    expect(actions.openProfileCalls, 1);
    expect(actions.openAppearanceCalls, 1);
    expect(actions.openPrivacyCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers Apple as an equivalent option on supported devices', (
    tester,
  ) async {
    final auth = _FakeAuthService(signedIn: false, appleSupported: true);
    final actions = _ActionLog();

    await tester.pumpWidget(_app(auth, actions));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);

    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(auth.appleSignInCalls, 1);
    expect(auth.signInCalls, 0);
  });

  testWidgets('serializes account actions and contains callback failures', (
    tester,
  ) async {
    final auth = _FakeAuthService(signedIn: false);
    final actions = _ActionLog()..pendingDeleteLocal = Completer<void>();

    await tester.pumpWidget(_app(auth, actions));
    await tester.pumpAndSettle();

    final deleteAction = find.widgetWithText(TextButton, 'Delete local data');
    final deleteButton = tester.widget<TextButton>(deleteAction);
    deleteButton.onPressed!.call();
    deleteButton.onPressed!.call();
    await tester.pump();

    expect(actions.deleteLocalCalls, 1);
    expect(tester.widget<TextButton>(deleteAction).onPressed, isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Sign in with Google'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'FocusHaven Pro'))
          .onPressed,
      isNull,
    );

    actions.pendingDeleteLocal!.completeError(Exception('action failed'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'That account action could not be completed. Please try again.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextButton>(deleteAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks duplicate sign-ins and contains unexpected failures', (
    tester,
  ) async {
    final auth = _FakeAuthService(signedIn: false);
    auth.pendingSignIn = Completer<UserCredential?>();
    final actions = _ActionLog();

    await tester.pumpWidget(_app(auth, actions));
    await tester.pumpAndSettle();

    final signInAction = find.widgetWithText(
      FilledButton,
      'Sign in with Google',
    );
    final signInButton = tester.widget<FilledButton>(signInAction);
    signInButton.onPressed!.call();
    signInButton.onPressed!.call();
    await tester.pump();

    expect(auth.signInCalls, 1);
    expect(find.text('Signing in…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Signing in…'),
          )
          .onPressed,
      isNull,
    );

    auth.pendingSignIn!.completeError(Exception('provider unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sign-in could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Sign in with Google'), findsOneWidget);
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
      expect(find.text('Delete account'), findsOneWidget);

      final signOutButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Sign out'),
      );
      signOutButton.onPressed!.call();
      await tester.pumpAndSettle();
      _invokeTextButton(tester, 'Delete cloud backup');
      await tester.pumpAndSettle();
      _invokeTextButton(tester, 'Delete account');
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(actions.deleteCloudCalls, 1);
      expect(actions.deleteAccountCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('blocks duplicate sign-outs and contains unexpected failures', (
    tester,
  ) async {
    final auth = _FakeAuthService(signedIn: true, name: 'Tyree Jones');
    auth.pendingSignOut = Completer<void>();
    final actions = _ActionLog();

    await tester.pumpWidget(_app(auth, actions));
    await tester.pumpAndSettle();

    final signOutAction = find.widgetWithText(OutlinedButton, 'Sign out');
    final signOutButton = tester.widget<OutlinedButton>(signOutAction);
    signOutButton.onPressed!.call();
    signOutButton.onPressed!.call();
    await tester.pump();

    expect(auth.signOutCalls, 1);
    expect(find.text('Signing out…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Signing out…'),
          )
          .onPressed,
      isNull,
    );

    auth.pendingSignOut!.completeError(Exception('provider unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sign-out could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
