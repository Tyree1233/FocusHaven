import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'soundscape_controller.dart';
import 'soundscape_media.dart';

/// One application-lifetime media session with fixed local brand artwork.
/// No remote URLs, user text, timer/queue controls or persisted playback intent.
Future<SoundscapeController> initializeSoundscapeAudio() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return SoundscapeController(
      UnavailableSoundscapeOutput(),
      available: false,
    );
  }
  final output = _LocalSoundOutput();
  final controller = SoundscapeController(output);
  try {
    final handler = _SoundHandler(controller);
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.focushaven.app.soundscapes',
        androidNotificationChannelName: 'FocusHaven sounds',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    output.handler = handler;
    return controller;
  } catch (_) {
    controller.dispose();
    return SoundscapeController(
      UnavailableSoundscapeOutput(),
      available: false,
    );
  }
}

class _LocalSoundOutput implements SoundscapeOutput {
  AudioPlayer? _player;
  AudioSession? _session;
  _SoundHandler? handler;
  final _playing = StreamController<bool>.broadcast();
  final _interruptions = StreamController<void>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  double _volume = 0.25;
  bool _disposed = false;
  int _playRevision = 0;
  Future<void> _operations = Future.value();
  bool _ownsSession = false;
  Uri? _artwork;

  Future<void> _serial(Future<void> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<void> get interruptions => _interruptions.stream;
  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> prepare() async {
    if (_disposed) throw StateError('Disposed');
    final session = await AudioSession.instance;
    if (_disposed) throw StateError('Disposed');
    _session = session;
    final player = AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
    _player = player;
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin && !_disposed) _interruptions.add(null);
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        if (!_disposed) _interruptions.add(null);
      }),
    );
    _subscriptions.add(
      player.playerStateStream.listen((state) {
        if (_disposed) return;
        _playing.add(state.playing);
        handler?.publish(state);
      }),
    );
    _subscriptions.add(
      player.errorStream.listen((error) {
        if (!_disposed) _errors.add(error);
      }),
    );
    await player.setVolume(_volume);
    await player.setLoopMode(LoopMode.one);
    await player.setAsset('assets/audio/soft_noise.wav');
    _artwork = await loadSoundscapeArtwork();
  }

  @override
  Future<void> start() {
    final revision = ++_playRevision;
    return _serial(() async {
      final player = _player;
      if (_disposed || player == null) throw StateError('Not ready');
      // Speech plugins share the platform session; restore playback configuration
      // only on an explicit play after the voice interlock is released.
      await _session!.configure(const AudioSessionConfiguration.music());
      if (_disposed || revision != _playRevision) return;
      if (!await _session!.setActive(true)) {
        throw StateError('Audio focus denied');
      }
      _ownsSession = true;
      if (_disposed || revision != _playRevision) {
        await _deactivate();
        return;
      }
      handler?.mediaItem.add(softNoiseMediaItem(artwork: _artwork));
      // play's future completes at pause/end, not when playback starts.
      unawaited(
        player.play().catchError((Object error) {
          if (!_disposed) _errors.add(error);
        }),
      );
    });
  }

  Future<void> _deactivate() async {
    if (!_ownsSession) return;
    _ownsSession = false;
    await _session?.setActive(false);
  }

  @override
  Future<void> pause() {
    ++_playRevision;
    return _serial(() async {
      await _player?.pause();
      await _deactivate();
    });
  }

  @override
  Future<void> stop() {
    ++_playRevision;
    return _serial(() async {
      await _player?.stop();
      await _deactivate();
      handler?.playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
    });
  }

  @override
  Future<void> setVolume(double value) async {
    _volume = value;
    await _player?.setVolume(value);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    ++_playRevision;
    await _operations;
    try {
      await _deactivate();
    } finally {
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      await _player?.dispose();
      await _playing.close();
      await _interruptions.close();
      await _errors.close();
    }
  }
}

class _SoundHandler extends BaseAudioHandler {
  _SoundHandler(this.controller);
  final SoundscapeController controller;

  void publish(PlayerState state) {
    playbackState.add(
      PlaybackState(
        controls: [
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1],
        processingState: switch (state.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: state.playing,
      ),
    );
  }

  @override
  Future<void> play() async {
    // A headset/media request cannot start sound on a fresh app launch.
    if (controller.mediaPlayAllowed) await controller.play();
  }

  @override
  Future<void> pause() async {
    await controller.pause();
  }

  @override
  Future<void> stop() => controller.stop();

  @override
  Future<void> onTaskRemoved() => controller.stop();
}
