import 'dart:ui' show Locale;

import '../services/account_deletion_service.dart';
import 'app_localizations.dart';

/// Services accept an [AppLocalizations] instance so the active production
/// catalog can reach business logic without giving it a widget context.
/// English remains the deterministic fallback when no UI locale is available.
AppLocalizations defaultServiceLocalizations() =>
    lookupAppLocalizations(const Locale('en'));

/// Maps stable account-deletion outcomes to catalog-owned presentation copy.
String localizeAccountDeletionResult(
  AppLocalizations l10n,
  AccountDeletionResult result,
) => switch (result.status) {
  AccountDeletionStatus.deleted => l10n.accountDeletionDeletedReceipt,
  AccountDeletionStatus.deletedAppleRevocationRequired =>
    l10n.accountDeletionAppleRevocationReceipt,
  AccountDeletionStatus.notSignedIn => l10n.accountDeletionNotSignedInReceipt,
  AccountDeletionStatus.reauthenticationCancelled =>
    l10n.accountDeletionCancelledReceipt,
  AccountDeletionStatus.reauthenticationUnavailable =>
    l10n.accountDeletionReauthenticationReceipt,
  AccountDeletionStatus.unsupportedProvider =>
    l10n.accountDeletionUnsupportedProviderReceipt,
  AccountDeletionStatus.unavailable => l10n.accountDeletionUnavailableReceipt,
};
