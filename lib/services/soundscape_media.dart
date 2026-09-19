import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const soundscapeArtworkAsset = 'assets/focushaven-lantern-icon.png';

/// Fixed, offline metadata only; never accepts user text or remote artwork.
MediaItem softNoiseMediaItem({Uri? artwork}) {
  if (artwork != null &&
      (artwork.scheme != 'file' ||
          artwork.host.isNotEmpty ||
          !artwork.path.startsWith('/'))) {
    throw ArgumentError('Soundscape artwork must be an absolute local file');
  }
  return MediaItem(
    id: 'focushaven.soft-noise.v1',
    title: 'Soft noise',
    album: 'FocusHaven',
    artist: 'FocusHaven',
    artUri: artwork,
  );
}

/// audio_service uses file artwork directly, without its network cache loader.
/// Recreate this app-owned copy on preparation so updated bundled art is used.
/// Artwork failure must not disable otherwise available sound playback.
Future<Uri?> loadSoundscapeArtwork({
  AssetBundle? bundle,
  Future<Directory> Function()? supportDirectory,
}) async {
  try {
    final data = await (bundle ?? rootBundle).load(soundscapeArtworkAsset);
    final support =
        await (supportDirectory ?? getApplicationSupportDirectory)();
    final directory = Directory('${support.path}/soundscape-media');
    await directory.create(recursive: true);
    final file = File('${directory.path}/focushaven-lantern.png');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.absolute.uri;
  } catch (_) {
    return null;
  }
}
