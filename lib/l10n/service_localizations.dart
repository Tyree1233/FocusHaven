import 'dart:ui' show Locale;

import '../services/account_deletion_service.dart';
import 'app_localizations.dart';

/// English remains the only production locale until a later locale is
/// independently reviewed and activated.
///
/// Services accept an [AppLocalizations] instance so future locale activation
/// can provide the selected catalog without giving business logic a widget
/// context. This fallback preserves today's single-locale runtime behavior.
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
