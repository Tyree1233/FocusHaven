import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Wear manifest registers one Tile and one complication data source', () {
    final manifest = _read('android/wear/src/main/AndroidManifest.xml');

    expect(manifest, contains('.SystemFocusWearTileService'));
    expect(manifest, contains('androidx.wear.tiles.action.BIND_TILE_PROVIDER'));
    expect(
      manifest,
      contains('com.google.android.wearable.permission.BIND_TILE_PROVIDER'),
    );
    expect(manifest, contains('.SystemFocusWearComplicationDataSourceService'));
    expect(
      manifest,
      contains(
        'android.support.wearable.complications.ACTION_COMPLICATION_UPDATE_REQUEST',
      ),
    );
    expect(manifest, contains('SHORT_TEXT,RANGED_VALUE'));
    expect(manifest, contains('UPDATE_PERIOD_SECONDS'));
    expect(manifest, contains('android:value="0"'));
  });

  test('background sync accepts only the exact schema-v2 snapshot path', () {
    final manifest = _read('android/wear/src/main/AndroidManifest.xml');
    final decoder = _read(
      'android/wear/src/main/kotlin/com/focushaven/app/wear/SystemFocusWearSnapshotData.kt',
    );
    final listener = _read(
      'android/wear/src/main/kotlin/com/focushaven/app/wear/SystemFocusWearSnapshotListenerService.kt',
    );
    final store = _read(
      'android/wear/src/main/kotlin/com/focushaven/app/wear/SystemFocusWearSnapshotStore.kt',
    );

    for (final source in <String>[manifest, decoder]) {
      expect(source, contains('/focus_haven/system_focus/snapshot/v2'));
    }
    expect(decoder, contains('SystemFocusWearSnapshot.WIRE_KEYS'));
    expect(decoder, contains('SystemFocusWearSnapshot.fromWireMap'));
    expect(listener, contains('SystemFocusWearSnapshotStore'));
    expect(listener, contains('SystemFocusWearSurfaceUpdater.request'));
    expect(store, contains('Context.MODE_PRIVATE'));
    expect(store, contains('snapshot.generatedAt <= existing.generatedAt'));
  });

  test('Tile and complication are read-only private projections', () {
    final tile = _read(
      'android/wear/src/main/kotlin/com/focushaven/app/wear/SystemFocusWearTileService.kt',
    );
    final complication = _read(
      'android/wear/src/main/kotlin/com/focushaven/app/wear/SystemFocusWearComplicationDataSourceService.kt',
    );
    final projection = _read(
      'android/wear/src/main/kotlin/com/focushaven/app/wear/SystemFocusWearGlanceContent.kt',
    );

    for (final source in <String>[tile, complication, projection]) {
      for (final privateContent in <String>[
        'task',
        'journal',
        'mood',
        'queue',
        'parkedThought',
        'coaching',
        'history',
        'account',
        'snapshotToken',
      ]) {
        expect(
          source,
          isNot(contains(privateContent)),
          reason: '$privateContent must never enter a Wear glance surface.',
        );
      }
      for (final commandBoundary in <String>[
        'SystemFocusWearCommand',
        'SystemFocusWearAction',
        'ACKNOWLEDGEMENT_PATH',
        'commandToken',
      ]) {
        expect(
          source,
          isNot(contains(commandBoundary)),
          reason:
              '$commandBoundary would make a glance surface a timer control.',
        );
      }
    }
    expect(tile, contains('FocusHavenWearActivity::class.java'));
    expect(complication, contains('FocusHavenWearActivity::class.java'));
    expect(complication, contains('TimeDifferenceComplicationText.Builder'));
  });
}

String _read(String path) => File(path).readAsStringSync();
