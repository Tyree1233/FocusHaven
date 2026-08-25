import 'dart:async';

import 'package:flutter/foundation.dart';

/// A closed set of technical events that may be emitted by debug builds.
///
/// Codes describe only a failed operation. They must never contain task names,
/// journal or coaching text, account identifiers, timer state, timestamps, or
/// any other user-derived value.
enum FocusHavenDiagnosticEvent {
  remoteCoachingAppCheckSetup('remote_coaching.app_check_setup'),
  focusProfileLoad('focus_profile.load'),
  reminderPreferencesLoad('reminder_preferences.load'),
  journalLoad('journal.load'),
  journalCorruptCleanup('journal.corrupt_cleanup'),
  authenticationStream('authentication.stream'),
  googleSignInCancelled('authentication.google_sign_in_cancelled'),
  googleSignIn('authentication.google_sign_in'),
  signOut('authentication.sign_out'),
  havenWindowReminderCleanup('haven_window.reminder_cleanup'),
  havenWindowHold('haven_window.hold'),
  havenWindowRelease('haven_window.release'),
  havenWindowLoad('haven_window.load'),
  havenWindowExpirationCleanup('haven_window.expiration_cleanup'),
  havenWindowInvalidCleanup('haven_window.invalid_cleanup'),
  havenWindowPendingCleanup('haven_window.pending_cleanup'),
  appearancePreferenceLoad('appearance_preference.load'),
  cloudBackupUpload('cloud_backup.upload'),
  cloudBackupDownload('cloud_backup.download'),
  cloudBackupDelete('cloud_backup.delete'),
  notificationInitialize('notification.initialize'),
  notificationPermission('notification.permission'),
  notificationDisplay('notification.display'),
  notificationPartialReminderCleanup('notification.partial_reminder_cleanup'),
  notificationDailyReminderSchedule('notification.daily_reminder_schedule'),
  notificationHavenWindowSchedule('notification.haven_window_schedule'),
  coachResponse('coach.response'),
  coachResponseRetry('coach.response_retry'),
  coachEnhancedPreferenceSave('coach.enhanced_preference_save'),
  coachPrivateCleanup('coach.private_cleanup'),
  coachConversationLoad('coach.conversation_load'),
  coachCorruptCleanup('coach.corrupt_cleanup'),
  coachPreferenceCleanup('coach.preference_cleanup'),
  coachStorageRepair('coach.storage_repair');

  const FocusHavenDiagnosticEvent(this.code);

  final String code;
}

enum FocusHavenDiagnosticErrorKind {
  argument,
  assertion,
  format,
  state,
  timeout,
  unsupported,
  other,
}

typedef FocusHavenDiagnosticSink = void Function(String message);

/// Emits a bounded developer signal without retaining or transmitting it.
///
/// Release builds take no action. Debug output contains only an allowlisted
/// event code and a coarse error category. The API intentionally accepts no
/// arbitrary metadata, exception message, stack trace, identifier, or user
/// content.
abstract final class PrivacySafeDiagnostics {
  static void report(
    FocusHavenDiagnosticEvent event, {
    Object? error,
    FocusHavenDiagnosticSink? debugSink,
  }) {
    if (!kDebugMode) return;

    final errorKind = error == null ? null : classifyError(error);
    final message = [
      '[FocusHaven diagnostic]',
      event.code,
      if (errorKind != null) 'error=${errorKind.name}',
    ].join(' ');

    if (debugSink != null) {
      debugSink(message);
    } else {
      debugPrint(message);
    }
  }

  @visibleForTesting
  static FocusHavenDiagnosticErrorKind classifyError(Object error) {
    if (error is TimeoutException) {
      return FocusHavenDiagnosticErrorKind.timeout;
    }
    if (error is FormatException) {
      return FocusHavenDiagnosticErrorKind.format;
    }
    if (error is ArgumentError) {
      return FocusHavenDiagnosticErrorKind.argument;
    }
    if (error is StateError) {
      return FocusHavenDiagnosticErrorKind.state;
    }
    if (error is UnsupportedError) {
      return FocusHavenDiagnosticErrorKind.unsupported;
    }
    if (error is AssertionError) {
      return FocusHavenDiagnosticErrorKind.assertion;
    }
    return FocusHavenDiagnosticErrorKind.other;
  }
}
