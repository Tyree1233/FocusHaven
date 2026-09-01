import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/service_localizations.dart';
import 'package:focushaven/services/account_deletion_service.dart';
import 'package:focushaven/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deletes only after verified Google reauthentication', () async {
    final auth = _FakeAuthService(
      signedIn: true,
      reauthentication: const AccountReauthenticationResult.verified(),
    );
    final backend = _FakeAccountDeletionBackend();
    final service = AccountDeletionService(authService: auth, backend: backend);

    final result = await service.deleteAccount();

    expect(result.status, AccountDeletionStatus.deleted);
    expect(backend.deleteCalls, 1);
    expect(auth.guestResetCalls, 1);
    expect(auth.revokedAuthorizationCode, isNull);
  });

  test('revokes Apple authorization before deleting the account', () async {
    final auth = _FakeAuthService(
      signedIn: true,
      reauthentication: const AccountReauthenticationResult.verified(
        appleAuthorizationCode: 'apple-authorization-code',
      ),
    );
    final backend = _FakeAccountDeletionBackend();
    final service = AccountDeletionService(authService: auth, backend: backend);

    final result = await service.deleteAccount();

    expect(result.status, AccountDeletionStatus.deleted);
    expect(auth.revokedAuthorizationCode, 'apple-authorization-code');
    expect(backend.deleteCalls, 1);
    expect(auth.guestResetCalls, 1);
  });

  test(
    'missing Apple revocation code does not block verified deletion',
    () async {
      final auth = _FakeAuthService(
        signedIn: true,
        reauthentication: const AccountReauthenticationResult.verified(
          requiresManualAppleRevocation: true,
        ),
      );
      final backend = _FakeAccountDeletionBackend();
      final service = AccountDeletionService(
        authService: auth,
        backend: backend,
      );

      final result = await service.deleteAccount();

      expect(
        result.status,
        AccountDeletionStatus.deletedAppleRevocationRequired,
      );
      expect(result.deleted, isTrue);
      expect(
        localizeAccountDeletionResult(defaultServiceLocalizations(), result),
        contains('Apple Account settings'),
      );
      expect(backend.deleteCalls, 1);
      expect(auth.guestResetCalls, 1);
    },
  );

  test('Apple revocation failure still fulfills verified deletion', () async {
    final auth = _FakeAuthService(
      signedIn: true,
      reauthentication: const AccountReauthenticationResult.verified(
        appleAuthorizationCode: 'apple-authorization-code',
      ),
    )..shouldFailRevocation = true;
    final backend = _FakeAccountDeletionBackend();
    final service = AccountDeletionService(authService: auth, backend: backend);

    final result = await service.deleteAccount();

    expect(result.status, AccountDeletionStatus.deletedAppleRevocationRequired);
    expect(result.deleted, isTrue);
    expect(auth.revokedAuthorizationCode, 'apple-authorization-code');
    expect(backend.deleteCalls, 1);
    expect(auth.guestResetCalls, 1);
  });

  test('cancelled verification cannot delete anything', () async {
    final auth = _FakeAuthService(
      signedIn: true,
      reauthentication: const AccountReauthenticationResult.cancelled(),
    );
    final backend = _FakeAccountDeletionBackend();
    final service = AccountDeletionService(authService: auth, backend: backend);

    final result = await service.deleteAccount();

    expect(result.status, AccountDeletionStatus.reauthenticationCancelled);
    expect(backend.deleteCalls, 0);
    expect(auth.guestResetCalls, 0);
  });

  test('server failure never claims deletion or resets the session', () async {
    final auth = _FakeAuthService(
      signedIn: true,
      reauthentication: const AccountReauthenticationResult.verified(),
    );
    final backend = _FakeAccountDeletionBackend()..shouldFail = true;
    final service = AccountDeletionService(authService: auth, backend: backend);

    final result = await service.deleteAccount();

    expect(result.status, AccountDeletionStatus.unavailable);
    expect(result.deleted, isFalse);
    expect(backend.deleteCalls, 1);
    expect(auth.guestResetCalls, 0);
  });

  test('signed-out and unsupported accounts fail closed', () async {
    final signedOutAuth = _FakeAuthService(
      signedIn: false,
      reauthentication: const AccountReauthenticationResult.unauthenticated(),
    );
    final unsupportedAuth = _FakeAuthService(
      signedIn: true,
      reauthentication:
          const AccountReauthenticationResult.unsupportedProvider(),
    );
    final backend = _FakeAccountDeletionBackend();

    expect(
      (await AccountDeletionService(
        authService: signedOutAuth,
        backend: backend,
      ).deleteAccount()).status,
      AccountDeletionStatus.notSignedIn,
    );
    expect(
      (await AccountDeletionService(
        authService: unsupportedAuth,
        backend: backend,
      ).deleteAccount()).status,
      AccountDeletionStatus.unsupportedProvider,
    );
    expect(backend.deleteCalls, 0);
  });
}

final class _FakeAuthService extends AuthService {
  _FakeAuthService({required this.signedIn, required this.reauthentication});

  final bool signedIn;
  final AccountReauthenticationResult reauthentication;
  String? revokedAuthorizationCode;
  bool shouldFailRevocation = false;
  int guestResetCalls = 0;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<AccountReauthenticationResult>
  reauthenticateForAccountDeletion() async => reauthentication;

  @override
  Future<void> revokeAppleAuthorization(String authorizationCode) async {
    revokedAuthorizationCode = authorizationCode;
    if (shouldFailRevocation) throw StateError('Apple revocation unavailable');
  }

  @override
  Future<void> establishGuestAfterAccountDeletion() async {
    guestResetCalls += 1;
  }
}

final class _FakeAccountDeletionBackend implements AccountDeletionBackend {
  int deleteCalls = 0;
  bool shouldFail = false;

  @override
  Future<void> deleteCurrentAccount() async {
    deleteCalls += 1;
    if (shouldFail) throw StateError('deletion unavailable');
  }
}
