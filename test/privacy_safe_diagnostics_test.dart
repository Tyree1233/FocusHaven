import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/privacy_safe_diagnostics.dart';

final class _PrivateError {
  _PrivateError(this.privateText);

  final String privateText;

  @override
  String toString() => 'Private content: $privateText';
}

final class _ThrowingStringError {
  @override
  String toString() => throw StateError('toString must not be called');
}

void main() {
  test('diagnostic codes are unique, bounded, and contain no free text', () {
    final codes = FocusHavenDiagnosticEvent.values
        .map((event) => event.code)
        .toList(growable: false);

    expect(codes.toSet(), hasLength(codes.length));
    for (final code in codes) {
      expect(code, matches(RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$')));
      expect(code.length, lessThanOrEqualTo(64));
    }
  });

  test('reports only an allowlisted event and a coarse error category', () {
    final messages = <String>[];

    PrivacySafeDiagnostics.report(
      FocusHavenDiagnosticEvent.coachResponse,
      error: StateError('private coaching text and account@example.com'),
      debugSink: messages.add,
    );

    expect(messages, ['[FocusHaven diagnostic] coach.response error=state']);
    expect(messages.single, isNot(contains('private coaching text')));
    expect(messages.single, isNot(contains('account@example.com')));
  });

  test('never calls an arbitrary error toString implementation', () {
    final messages = <String>[];

    PrivacySafeDiagnostics.report(
      FocusHavenDiagnosticEvent.journalLoad,
      error: _ThrowingStringError(),
      debugSink: messages.add,
    );

    expect(messages, ['[FocusHaven diagnostic] journal.load error=other']);
  });

  test('cannot expose private values carried by unknown errors', () {
    final messages = <String>[];

    PrivacySafeDiagnostics.report(
      FocusHavenDiagnosticEvent.cloudBackupUpload,
      error: _PrivateError('task, reflection, uid, and access token'),
      debugSink: messages.add,
    );

    expect(messages.single, endsWith('error=other'));
    expect(messages.single, isNot(contains('task')));
    expect(messages.single, isNot(contains('reflection')));
    expect(messages.single, isNot(contains('uid')));
    expect(messages.single, isNot(contains('token')));
  });

  test('uses stable categories without preserving exception messages', () {
    expect(
      PrivacySafeDiagnostics.classifyError(ArgumentError('private')),
      FocusHavenDiagnosticErrorKind.argument,
    );
    expect(
      PrivacySafeDiagnostics.classifyError(AssertionError('private')),
      FocusHavenDiagnosticErrorKind.assertion,
    );
    expect(
      PrivacySafeDiagnostics.classifyError(const FormatException('private')),
      FocusHavenDiagnosticErrorKind.format,
    );
    expect(
      PrivacySafeDiagnostics.classifyError(StateError('private')),
      FocusHavenDiagnosticErrorKind.state,
    );
    expect(
      PrivacySafeDiagnostics.classifyError(TimeoutException('private')),
      FocusHavenDiagnosticErrorKind.timeout,
    );
    expect(
      PrivacySafeDiagnostics.classifyError(UnsupportedError('private')),
      FocusHavenDiagnosticErrorKind.unsupported,
    );
  });

  test('events without errors expose only the event code', () {
    final messages = <String>[];

    PrivacySafeDiagnostics.report(
      FocusHavenDiagnosticEvent.googleSignInCancelled,
      debugSink: messages.add,
    );

    expect(messages, [
      '[FocusHaven diagnostic] authentication.google_sign_in_cancelled',
    ]);
  });
}
