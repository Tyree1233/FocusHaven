import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Watch app embeds one WidgetKit complication extension', () {
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    final info = _read('ios/FocusHavenWatchWidget/Info.plist');

    expect(
      project,
      contains('FocusHavenWatchWidget.appex in Embed App Extensions'),
    );
    expect(
      project,
      contains(
        'Build configuration list for PBXNativeTarget "FocusHavenWatchWidget"',
      ),
    );
    expect(project, contains('com.focushaven.app.watchkitapp.widget'));
    expect(project, contains('WATCHOS_DEPLOYMENT_TARGET = 10.0;'));
    expect(info, contains('com.apple.widgetkit-extension'));
  });

  test('every supported complication family is private and read-only', () {
    final widget = _read(
      'ios/FocusHavenWatchWidget/FocusHavenWatchWidget.swift',
    );

    for (final family in <String>[
      '.accessoryInline',
      '.accessoryCircular',
      '.accessoryRectangular',
      '.accessoryCorner',
    ]) {
      expect(widget, contains(family));
    }
    for (final commandSurface in <String>[
      'Button(',
      'Link(',
      '.widgetURL',
      'commandURL',
      'controlToken',
      'system-focus-command',
    ]) {
      expect(
        widget,
        isNot(contains(commandSurface)),
        reason: '$commandSurface would make the complication interactive.',
      );
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
    ]) {
      expect(
        widget,
        isNot(contains(privateContent)),
        reason: '$privateContent must never enter a Watch complication.',
      );
    }
  });

  test('Watch app and complication share only the validated snapshot', () {
    final store = _read(
      'ios/FocusHavenWatch/SystemFocusWatchSnapshotStore.swift',
    );
    final model = _read('ios/FocusHavenWatch/SystemFocusWatchModel.swift');
    final watchEntitlements = _read(
      'ios/FocusHavenWatch/FocusHavenWatch.entitlements',
    );
    final complicationEntitlements = _read(
      'ios/FocusHavenWatchWidget/FocusHavenWatchWidget.entitlements',
    );

    for (final source in <String>[
      store,
      watchEntitlements,
      complicationEntitlements,
    ]) {
      expect(source, contains('group.com.focushaven.app'));
    }
    expect(store, contains('SystemFocusWatchSnapshot.fromWireDictionary'));
    expect(model, contains('WidgetCenter.shared.reloadTimelines'));
    expect(model, contains('SystemFocusWatchComplicationContent.widgetKind'));
  });
}

String _read(String path) => File(path).readAsStringSync();
