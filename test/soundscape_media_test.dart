import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/soundscape_media.dart';

class _ArtworkBundle extends CachingAssetBundle {
  _ArtworkBundle(this.data);
  final ByteData data;

  @override
  Future<ByteData> load(String key) async {
    expect(key, soundscapeArtworkAsset);
    return data;
  }
}

class _MissingArtworkBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('Missing fixture');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('soundscape-media-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('fixed title and creator remain available without artwork', () {
    final item = softNoiseMediaItem();
    expect(item.id, 'focushaven.soft-noise.v1');
    expect(item.title, 'Soft noise');
    expect(item.album, 'FocusHaven');
    expect(item.artist, 'FocusHaven');
    expect(item.artUri, isNull);
  });

  test('local artwork is preserved without changing media identity', () {
    final uri = File('${directory.path}/brand.png').uri;
    final item = softNoiseMediaItem(artwork: uri);
    expect(item.artUri, uri);
    expect(item.artist, 'FocusHaven');
    expect(item.id, softNoiseMediaItem().id);
    expect(item.title, softNoiseMediaItem().title);
  });

  test('remote, host-qualified and relative artwork are rejected', () {
    for (final value in [
      'https://example.invalid/brand.png',
      'http://example.invalid/brand.png',
      'file://remote/brand.png',
      'brand.png',
      'assets/brand.png',
    ]) {
      expect(
        () => softNoiseMediaItem(artwork: Uri.parse(value)),
        throwsArgumentError,
      );
    }
  });

  test('Dart normalizes file scheme paths before metadata validation', () {
    final artwork = Uri.parse('file:brand.png');
    expect(artwork, Uri.file('/brand.png'));
    expect(artwork.path, '/brand.png');
    expect(softNoiseMediaItem(artwork: artwork).artUri, artwork);
  });

  test(
    'actual bundled lantern is copied byte-exactly to a local URI',
    () async {
      final expected = await rootBundle.load(soundscapeArtworkAsset);
      final uri = await loadSoundscapeArtwork(
        supportDirectory: () async => directory,
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'file');
      expect(uri.host, isEmpty);
      expect(
        await File.fromUri(uri).readAsBytes(),
        expected.buffer.asUint8List(
          expected.offsetInBytes,
          expected.lengthInBytes,
        ),
      );
      expect(softNoiseMediaItem(artwork: uri).artUri, uri);
    },
  );

  test('only the requested ByteData slice is written', () async {
    final bytes = Uint8List.fromList([99, 1, 2, 3, 99]);
    final uri = await loadSoundscapeArtwork(
      bundle: _ArtworkBundle(ByteData.view(bytes.buffer, 1, 3)),
      supportDirectory: () async => directory,
    );
    expect(uri, isNotNull);
    expect(await File.fromUri(uri!).readAsBytes(), [1, 2, 3]);
  });

  test('preparation refreshes only the generated artwork copy', () async {
    final unrelated = File('${directory.path}/keep.txt');
    await unrelated.writeAsString('unchanged');
    Future<Uri?> load(List<int> bytes) => loadSoundscapeArtwork(
      bundle: _ArtworkBundle(ByteData.sublistView(Uint8List.fromList(bytes))),
      supportDirectory: () async => directory,
    );
    final first = await load([1, 2]);
    final second = await load([3, 4]);
    expect(first, isNotNull);
    expect(second, first);
    expect(await File.fromUri(second!).readAsBytes(), [3, 4]);
    expect(await unrelated.readAsString(), 'unchanged');
  });

  test('missing artwork retains usable text metadata', () async {
    final uri = await loadSoundscapeArtwork(
      bundle: _MissingArtworkBundle(),
      supportDirectory: () async => directory,
    );
    expect(uri, isNull);
    expect(softNoiseMediaItem(artwork: uri).artist, 'FocusHaven');
  });

  test('unavailable app storage falls back without throwing', () async {
    final uri = await loadSoundscapeArtwork(
      bundle: _ArtworkBundle(ByteData(1)),
      supportDirectory: () async => throw FileSystemException('Unavailable'),
    );
    expect(uri, isNull);
  });

  test('an unwritable destination falls back without throwing', () async {
    await File(
      '${directory.path}/soundscape-media',
    ).writeAsString('not a directory');
    final uri = await loadSoundscapeArtwork(
      bundle: _ArtworkBundle(ByteData(1)),
      supportDirectory: () async => directory,
    );
    expect(uri, isNull);
  });
}
