import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/haven_window_suggestion.dart';
import 'package:focushaven/widgets/haven_window_card.dart';

const _unavailable = HavenWindowSuggestion(
  kind: HavenWindowKind.unavailable,
  headline: 'Calendar availability is unavailable here',
  detail: 'No supported private calendar connection is available.',
  evidence: 'No calendar availability was read.',
);

const _learning = HavenWindowSuggestion(
  kind: HavenWindowKind.learning,
  headline: 'Your Haven Window is still forming',
  detail: 'FocusHaven is waiting for a clear completed-session pattern.',
  evidence: 'The private Focus Forecast is still learning.',
);

const _noOpening = HavenWindowSuggestion(
  kind: HavenWindowKind.noOpening,
  headline: 'No matching Haven Window appears right now',
  detail: 'Nothing needs to be forced.',
  evidence: 'No 25-minute opening overlaps the forecast window.',
);

final _opening = HavenWindowSuggestion(
  kind: HavenWindowKind.opening,
  headline: 'A possible Haven Window is open',
  detail: 'Review this optional opening before deciding whether it fits.',
  evidence: 'One 25-minute opening fits the morning forecast window.',
  startsAt: DateTime(2026, 8, 18, 9),
  endsAt: DateTime(2026, 8, 18, 9, 25),
);

Widget _app({
  HavenWindowSuggestion suggestion = _unavailable,
  PrivateCalendarAvailabilityStatus status =
      PrivateCalendarAvailabilityStatus.unsupported,
  bool isPlatformStarted = false,
  bool isHeld = false,
  bool hasArrived = false,
  DateTime? heldStartsAtUtc,
  DateTime? heldEndsAtUtc,
  bool isHoldUpdating = false,
  Future<bool> Function()? onRequestReadOnlyAccess,
  Future<bool> Function()? onRefreshAvailability,
  Future<bool> Function()? onHoldWindow,
  Future<bool> Function()? onReleaseHold,
  Future<bool> Function()? onBeginFocus,
  double textScale = 1,
  double cardWidth = 380,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark().copyWith(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFF16FBA),
      secondary: Color(0xFFF58FC0),
      tertiary: Color(0xFFC58BFF),
      surface: Color(0xFF352260),
    ),
  ),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: cardWidth,
          child: HavenWindowCard(
            suggestion: suggestion,
            availabilityStatus: status,
            isPlatformStarted: isPlatformStarted,
            isHeld: isHeld,
            hasArrived: hasArrived,
            heldStartsAtUtc: heldStartsAtUtc,
            heldEndsAtUtc: heldEndsAtUtc,
            isHoldUpdating: isHoldUpdating,
            onRequestReadOnlyAccess: onRequestReadOnlyAccess,
            onRefreshAvailability: onRefreshAvailability,
            onHoldWindow: onHoldWindow,
            onReleaseHold: onReleaseHold,
            onBeginFocus: onBeginFocus,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'labels dormant and connected states without overstating access',
    (tester) async {
      final cases =
          <
            ({
              PrivateCalendarAvailabilityStatus status,
              bool started,
              HavenWindowSuggestion suggestion,
              String label,
            })
          >[
            (
              status: PrivateCalendarAvailabilityStatus.unsupported,
              started: false,
              suggestion: _unavailable,
              label: 'OFF',
            ),
            (
              status: PrivateCalendarAvailabilityStatus.unsupported,
              started: true,
              suggestion: _unavailable,
              label: 'UNAVAILABLE',
            ),
            (
              status: PrivateCalendarAvailabilityStatus.disconnected,
              started: true,
              suggestion: _unavailable,
              label: 'NOT CONNECTED',
            ),
            (
              status: PrivateCalendarAvailabilityStatus.denied,
              started: true,
              suggestion: _unavailable,
              label: 'ACCESS OFF',
            ),
            (
              status: PrivateCalendarAvailabilityStatus.ready,
              started: true,
              suggestion: _learning,
              label: 'STILL LEARNING',
            ),
            (
              status: PrivateCalendarAvailabilityStatus.ready,
              started: true,
              suggestion: _opening,
              label: 'POSSIBLE OPENING',
            ),
            (
              status: PrivateCalendarAvailabilityStatus.ready,
              started: true,
              suggestion: _noOpening,
              label: 'NO OPENING',
            ),
          ];

      for (final value in cases) {
        await tester.pumpWidget(
          _app(
            suggestion: value.suggestion,
            status: value.status,
            isPlatformStarted: value.started,
          ),
        );

        expect(find.text('HAVEN WINDOW · ${value.label}'), findsOneWidget);
        expect(find.textContaining('scheduled'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('exposes one complete screen-reader toggle description', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app());

      expect(
        find.bySemanticsLabel(
          'Haven Window. Off. Calendar assistance stays off. Show details.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
      await tester.pump();
      expect(
        find.bySemanticsLabel(
          'Haven Window. Off. Calendar assistance stays off. Hide details.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('dormant details stay honest and expose no inert controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        onRequestReadOnlyAccess: () async => true,
        onRefreshAvailability: () async => true,
      ),
    );

    expect(find.byKey(const ValueKey('haven-window-details')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    expect(find.textContaining('has not checked or requested'), findsOneWidget);
    expect(find.text('No calendar availability was read.'), findsOneWidget);
    expect(find.textContaining('Event titles'), findsOneWidget);
    expect(find.textContaining('never creates or changes'), findsOneWidget);
    expect(find.byType(ButtonStyleButton), findsNothing);
  });

  testWidgets('disconnected state offers only explicit access review', (
    tester,
  ) async {
    var requestCount = 0;
    var refreshCount = 0;
    await tester.pumpWidget(
      _app(
        status: PrivateCalendarAvailabilityStatus.disconnected,
        isPlatformStarted: true,
        onRequestReadOnlyAccess: () async {
          requestCount += 1;
          return true;
        },
        onRefreshAvailability: () async {
          refreshCount += 1;
          return true;
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    expect(find.text('Review calendar access'), findsOneWidget);
    expect(find.text('Refresh private availability'), findsNothing);
    expect(find.text('Recheck access'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('haven-window-request-access')));
    await tester.pumpAndSettle();
    expect(requestCount, 1);
    expect(refreshCount, 0);
  });

  testWidgets('denied and ready states only offer a non-prompting refresh', (
    tester,
  ) async {
    for (final value in [
      (
        status: PrivateCalendarAvailabilityStatus.denied,
        suggestion: _unavailable,
        key: 'haven-window-refresh-access',
        label: 'Recheck access',
      ),
      (
        status: PrivateCalendarAvailabilityStatus.ready,
        suggestion: _learning,
        key: 'haven-window-refresh-availability',
        label: 'Refresh private availability',
      ),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      var refreshCount = 0;
      await tester.pumpWidget(
        _app(
          status: value.status,
          suggestion: value.suggestion,
          isPlatformStarted: true,
          onRequestReadOnlyAccess: () async => true,
          onRefreshAvailability: () async {
            refreshCount += 1;
            return true;
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
      await tester.pump();

      expect(find.text(value.label), findsOneWidget);
      expect(find.text('Review calendar access'), findsNothing);
      await tester.tap(find.byKey(ValueKey(value.key)));
      await tester.pumpAndSettle();
      expect(refreshCount, 1);
    }
  });

  testWidgets('serializes an in-flight consent action', (tester) async {
    final gate = Completer<bool>();
    var requestCount = 0;
    await tester.pumpWidget(
      _app(
        status: PrivateCalendarAvailabilityStatus.disconnected,
        isPlatformStarted: true,
        onRequestReadOnlyAccess: () {
          requestCount += 1;
          return gate.future;
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();
    final action = find.byKey(const ValueKey('haven-window-request-access'));

    await tester.tap(action);
    await tester.pump();
    await tester.tap(action);
    await tester.pump();

    expect(requestCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a possible opening waits for one explicit hold action', (
    tester,
  ) async {
    var holdCount = 0;
    var refreshCount = 0;
    await tester.pumpWidget(
      _app(
        suggestion: _opening,
        status: PrivateCalendarAvailabilityStatus.ready,
        isPlatformStarted: true,
        onHoldWindow: () async {
          holdCount += 1;
          return true;
        },
        onRefreshAvailability: () async {
          refreshCount += 1;
          return true;
        },
      ),
    );

    expect(holdCount, 0);
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    expect(find.text('Hold this window'), findsOneWidget);
    expect(find.text('Refresh private availability'), findsOneWidget);
    expect(find.textContaining('one generic local reminder'), findsOneWidget);
    expect(find.textContaining('does not reserve time'), findsOneWidget);
    expect(holdCount, 0);

    await tester.tap(find.byKey(const ValueKey('haven-window-hold')));
    await tester.pumpAndSettle();
    expect(holdCount, 1);
    expect(refreshCount, 0);
  });

  testWidgets('a held reminder stays local and exposes only release', (
    tester,
  ) async {
    var holdCount = 0;
    var releaseCount = 0;
    var refreshCount = 0;
    await tester.pumpWidget(
      _app(
        suggestion: _opening,
        status: PrivateCalendarAvailabilityStatus.ready,
        isPlatformStarted: true,
        isHeld: true,
        heldStartsAtUtc: _opening.startsAt!.toUtc(),
        heldEndsAtUtc: _opening.endsAt!.toUtc(),
        onHoldWindow: () async {
          holdCount += 1;
          return true;
        },
        onReleaseHold: () async {
          releaseCount += 1;
          return true;
        },
        onRefreshAvailability: () async {
          refreshCount += 1;
          return true;
        },
      ),
    );

    expect(find.text('HAVEN WINDOW · REMINDER HELD'), findsOneWidget);
    expect(find.text('One private reminder is held'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    expect(find.text('Release hold'), findsOneWidget);
    expect(find.text('Hold this window'), findsNothing);
    expect(find.text('Refresh private availability'), findsNothing);
    expect(find.textContaining('not a calendar reservation'), findsOneWidget);
    expect(find.textContaining('cancels only this reminder'), findsOneWidget);

    final releaseAction = find.byKey(
      const ValueKey('haven-window-release-hold'),
    );
    await tester.ensureVisible(releaseAction);
    await tester.tap(releaseAction);
    await tester.pumpAndSettle();
    expect(releaseCount, 1);
    expect(holdCount, 0);
    expect(refreshCount, 0);
  });

  testWidgets('an arrived window waits for an explicit focus choice', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var beginCount = 0;
      var passCount = 0;
      await tester.pumpWidget(
        _app(
          suggestion: _opening,
          status: PrivateCalendarAvailabilityStatus.ready,
          isPlatformStarted: true,
          isHeld: true,
          hasArrived: true,
          heldStartsAtUtc: _opening.startsAt!.toUtc(),
          heldEndsAtUtc: _opening.endsAt!.toUtc(),
          onBeginFocus: () async {
            beginCount += 1;
            return true;
          },
          onReleaseHold: () async {
            passCount += 1;
            return true;
          },
        ),
      );

      expect(find.text('HAVEN WINDOW · WINDOW ARRIVED'), findsOneWidget);
      expect(find.text('Your optional Haven Window is here'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Haven Window. Window arrived. Your optional Haven Window is here. Show details.',
        ),
        findsOneWidget,
      );
      expect(beginCount, 0);
      expect(passCount, 0);
      await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
      await tester.pump();

      expect(find.textContaining('nothing has started'), findsOneWidget);
      expect(find.textContaining('Focus remains stopped'), findsOneWidget);
      expect(find.text('Begin focus'), findsOneWidget);
      expect(find.text('Let this window pass'), findsOneWidget);
      expect(find.text('Release hold'), findsNothing);

      final beginAction = find.byKey(
        const ValueKey('haven-window-begin-focus'),
      );
      await tester.ensureVisible(beginAction);
      await tester.tap(beginAction);
      await tester.pumpAndSettle();
      expect(beginCount, 1);
      expect(passCount, 0);

      final passAction = find.byKey(const ValueKey('haven-window-let-pass'));
      await tester.ensureVisible(passAction);
      await tester.tap(passAction);
      await tester.pumpAndSettle();
      expect(beginCount, 1);
      expect(passCount, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('an arrived window never invents an unavailable start action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        isHeld: true,
        hasArrived: true,
        heldStartsAtUtc: _opening.startsAt!.toUtc(),
        heldEndsAtUtc: _opening.endsAt!.toUtc(),
        onReleaseHold: () async => true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    expect(find.text('Begin focus'), findsNothing);
    expect(find.text('Let this window pass'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes an in-flight hold action', (tester) async {
    final gate = Completer<bool>();
    var holdCount = 0;
    await tester.pumpWidget(
      _app(
        suggestion: _opening,
        status: PrivateCalendarAvailabilityStatus.ready,
        isPlatformStarted: true,
        onHoldWindow: () {
          holdCount += 1;
          return gate.future;
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();
    final action = find.byKey(const ValueKey('haven-window-hold'));

    await tester.tap(action);
    await tester.pump();
    await tester.tap(action, warnIfMissed: false);
    await tester.pump();

    expect(holdCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('supports a narrow surface and large accessible text', (
    tester,
  ) async {
    await tester.pumpWidget(_app(textScale: 2, cardWidth: 260));
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    expect(find.text('HAVEN WINDOW · OFF'), findsOneWidget);
    expect(find.textContaining('No calendar availability'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
