import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iPhone opts into a guarded Live Activity lifecycle', () {
    final info = _read('ios/Runner/Info.plist');
    final controller = _read(
      'ios/Runner/SystemFocusLiveActivityController.swift',
    );
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');

    expect(
      info,
      matches(RegExp(r'<key>NSSupportsLiveActivities</key>\s*<true/>')),
    );
    expect(controller, contains('@available(iOS 16.1, *)'));
    expect(controller, contains('ActivityAuthorizationInfo'));
    expect(controller, contains('.areActivitiesEnabled'));
    expect(controller, contains('ActivityContent('));
    expect(controller, contains('staleDate: state.staleDate'));
    expect(controller, contains('Activity.request('));
    expect(controller, contains('await activity.update'));
    expect(controller, contains('await activity.end'));
    expect(
      project,
      contains('SystemFocusLiveActivityController.swift in Sources'),
    );
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(project).length,
      greaterThanOrEqualTo(4),
      reason: 'The guarded Live Activity must not remove iOS 15 support.',
    );
  });

  test('Live Activity and Dynamic Island expose every read-only region', () {
    final widget = _read('ios/FocusHavenWidget/FocusHavenWidget.swift');
    final start = widget.indexOf('struct FocusHavenLiveActivity: Widget');
    final end = widget.indexOf('@main\nstruct FocusHavenWidgetBundle', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final liveSurface = widget.substring(start, end);

    expect(liveSurface, contains('ActivityConfiguration('));
    expect(
      widget,
      contains('if #available(iOSApplicationExtension 16.2, *)'),
      reason: 'ActivityViewContext.isStale requires an iOS 16.2 guard.',
    );
    for (final region in <String>[
      'DynamicIslandExpandedRegion(.leading)',
      'DynamicIslandExpandedRegion(.trailing)',
      'DynamicIslandExpandedRegion(.center)',
      'DynamicIslandExpandedRegion(.bottom)',
      '} compactLeading:',
      '} compactTrailing:',
      '} minimal:',
    ]) {
      expect(liveSurface, contains(region));
    }
    for (final commandSurface in <String>[
      'Link(',
      'Button(',
      '.widgetURL',
      'commandURL',
      'controlToken',
      'system-focus-command',
    ]) {
      expect(
        liveSurface,
        isNot(contains(commandSurface)),
        reason: '$commandSurface would make the Live Activity interactive.',
      );
    }
  });

  test('Live Activity state remains bounded and private by construction', () {
    final model = _read('ios/Runner/SystemFocusWidgetContent.swift');
    final start = model.indexOf('struct SystemFocusLiveActivityState');
    final end = model.indexOf('enum SystemFocusLiveActivityOperation', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final state = model.substring(start, end);
    for (final required in <String>[
      'session',
      'activity',
      'secondsRemaining',
      'totalSessionSeconds',
      'snapshotGeneratedAt',
      'endsAt',
    ]) {
      expect(state, contains(required));
    }
    for (final privateContent in <String>[
      'task',
      'journal',
      'mood',
      'queue',
      'parkedThought',
      'coaching',
      'history',
      'account',
      'controlToken',
    ]) {
      expect(
        state,
        isNot(contains(privateContent)),
        reason: '$privateContent must never enter Live Activity state.',
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
