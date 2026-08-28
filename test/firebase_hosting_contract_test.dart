import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase CLI and Hosting stay pinned to the production project', () {
    final projectAliases = _readJson('.firebaserc');
    final firebase = _readJson('firebase.json');

    expect(projectAliases, <String, Object?>{
      'projects': <String, Object?>{'default': 'focushaven-68c59'},
    });

    final hosting = firebase['hosting']! as Map<String, Object?>;
    expect(hosting['site'], 'focushaven-68c59');
    expect(hosting['public'], 'build/web');
    expect(hosting['rewrites'], <Object?>[
      <String, Object?>{'source': '**', 'destination': '/index.html'},
    ]);
  });

  test('Hosting configuration contains no App Check credential', () {
    final configuration =
        '${File('.firebaserc').readAsStringSync()}\n'
        '${File('firebase.json').readAsStringSync()}';

    expect(configuration, isNot(contains('FIREBASE_APP_CHECK_WEB_SITE_KEY')));
    expect(configuration, isNot(contains('site-key')));
    expect(configuration, isNot(contains('secret')));
  });
}

Map<String, Object?> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
}
