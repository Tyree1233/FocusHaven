import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'privacy_safe_diagnostics.dart';

abstract interface class AccountDeletionBackend {
  Future<void> deleteCurrentAccount();
}

final class AccountDeletionFunctionException implements Exception {
  const AccountDeletionFunctionException(this.code);

  final String code;
}

final class FirebaseAccountDeletionBackend implements AccountDeletionBackend {
  FirebaseAccountDeletionBackend({
    FirebaseFunctions? functions,
    this.functionName = 'deleteFocusHavenAccount',
    this.timeout = const Duration(seconds: 30),
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;
  final String functionName;
  final Duration timeout;

  @override
  Future<void> deleteCurrentAccount() async {
    final callable = _functions.httpsCallable(
      functionName,
      options: HttpsCallableOptions(
        timeout: timeout,
        limitedUseAppCheckToken: true,
      ),
    );
    try {
      final response = await callable.call<Object?>(const <String, Object?>{});
      final data = response.data;
      if (data is! Map || data['deleted'] != true) {
        throw const FormatException('Invalid account-deletion response.');
      }
    } on FirebaseFunctionsException catch (error) {
      throw AccountDeletionFunctionException(error.code);
    }
  }
}

enum AccountDeletionStatus {
  deleted,
  deletedAppleRevocationRequired,
  notSignedIn,
  reauthenticationCancelled,
  reauthenticationUnavailable,
  unsupportedProvider,
  unavailable,
}

@immutable
final class AccountDeletionResult {
  const AccountDeletionResult(this.status);

  final AccountDeletionStatus status;

  bool get deleted =>
      status == AccountDeletionStatus.deleted ||
      status == AccountDeletionStatus.deletedAppleRevocationRequired;
}

class AccountDeletionService {
  AccountDeletionService({
    required this.authService,
    AccountDeletionBackend? backend,
  }) : _backend = backend ?? FirebaseAccountDeletionBackend();

  final AuthService authService;
  final AccountDeletionBackend _backend;

  Future<AccountDeletionResult> deleteAccount() async {
    if (!authService.isSignedIn) {
      return const AccountDeletionResult(AccountDeletionStatus.notSignedIn);
    }

    final reauthentication = await authService
        .reauthenticateForAccountDeletion();
    switch (reauthentication.status) {
      case AccountReauthenticationStatus.cancelled:
        return const AccountDeletionResult(
          AccountDeletionStatus.reauthenticationCancelled,
        );
      case AccountReauthenticationStatus.unauthenticated:
        return const AccountDeletionResult(AccountDeletionStatus.notSignedIn);
      case AccountReauthenticationStatus.unsupportedProvider:
        return const AccountDeletionResult(
          AccountDeletionStatus.unsupportedProvider,
        );
      case AccountReauthenticationStatus.unavailable:
        return const AccountDeletionResult(
          AccountDeletionStatus.reauthenticationUnavailable,
        );
      case AccountReauthenticationStatus.verified:
        break;
    }

    var requiresManualAppleRevocation =
        reauthentication.requiresManualAppleRevocation;
    final appleAuthorizationCode = reauthentication.appleAuthorizationCode
        ?.trim();
    if (appleAuthorizationCode != null && appleAuthorizationCode.isNotEmpty) {
      try {
        await authService.revokeAppleAuthorization(appleAuthorizationCode);
      } catch (error) {
        requiresManualAppleRevocation = true;
        PrivacySafeDiagnostics.report(
          FocusHavenDiagnosticEvent.accountAppleRevocation,
          error: error,
        );
      }
    }

    try {
      await _backend.deleteCurrentAccount();
      await authService.establishGuestAfterAccountDeletion();
      return AccountDeletionResult(
        requiresManualAppleRevocation
            ? AccountDeletionStatus.deletedAppleRevocationRequired
            : AccountDeletionStatus.deleted,
      );
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.accountDeletion,
        error: error,
      );
      return const AccountDeletionResult(AccountDeletionStatus.unavailable);
    }
  }
}
