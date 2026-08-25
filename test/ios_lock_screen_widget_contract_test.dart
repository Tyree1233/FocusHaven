import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS 16 adds every Lock Screen family without dropping iOS 15 homes',
    () {
      final widget = _read('ios/FocusHavenWidget/FocusHavenWidget.swift');
      final project = _read('ios/Runner.xcodeproj/project.pbxproj');

      expect(widget, contains('#available(iOSApplicationExtension 16.0, *)'));
      for (final family in <String>[
        '.systemSmall',
        '.systemMedium',
        '.accessoryInline',
        '.accessoryCircular',
        '.accessoryRectangular',
      ]) {
        expect(widget, contains(family));
      }
      expect(
        RegExp(
          r'CODE_SIGN_ENTITLEMENTS = '
          r'FocusHavenWidget/FocusHavenWidget\.entitlements;'
          r'[\s\S]{0,400}?IPHONEOS_DEPLOYMENT_TARGET = 15\.0;',
        ).allMatches(project).length,
        3,
        reason: 'Adding Lock Screen families must not drop iOS 15 app support.',
      );
    },
  );

  test('Lock Screen layouts remain private read-only status surfaces', () {
    final widget = _read('ios/FocusHavenWidget/FocusHavenWidget.swift');
    final start = widget.indexOf('private func accessoryAvailableView');
    final end = widget.indexOf('private var accessoryUnavailableView', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final accessoryLayouts = widget.substring(start, end);

    for (final commandSurface in <String>[
      'commandLink',
      'commandURL',
      'controlToken',
      'Link(',
      '.widgetURL',
    ]) {
      expect(
        accessoryLayouts,
        isNot(contains(commandSurface)),
        reason: '$commandSurface would make the locked surface interactive.',
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
        accessoryLayouts,
        isNot(contains(privateContent)),
        reason: '$privateContent must never enter a Lock Screen layout.',
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
