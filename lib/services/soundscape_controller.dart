import 'dart:async';

import 'package:flutter/foundation.dart';

/// Sound only. This boundary has no timer, queue, account or action-engine owner.
abstract interface class SoundscapeOutput {
  Stream<bool> get playing;
  Stream<void> get interruptions;
  Stream<Object> get errors;
  Future<void> prepare();
  Future<void> start();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double value);
  Future<void> dispose();
}

enum SoundscapeStatus { off, loading, playing, paused, failed }

class SoundscapeController extends ChangeNotifier {
  SoundscapeController(this._output, {this.available = true}) {
    _subscriptions.add(
      _output.playing.listen((playing) {
        if (_disposed) return;
        if (playing && (!_wantsPlayback || _voiceActive)) {
          unawaited(pause());
          return;
        }
        if (_status == SoundscapeStatus.failed) return;
        if (playing) {
          _status = SoundscapeStatus.playing;
        } else if (_status == SoundscapeStatus.playing) {
          _status = SoundscapeStatus.paused;
        }
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _output.interruptions.listen((_) {
        unawaited(pause());
      }),
    );
    _subscriptions.add(
      _output.errors.listen((_) {
        _fail();
      }),
    );
  }

  final SoundscapeOutput _output;
  final bool available;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void>? _preparation;
  Future<bool>? _pendingSilence;
  SoundscapeStatus _status = SoundscapeStatus.off;
  double _volume = 0.25;
  int _revision = 0;
  bool _wantsPlayback = false;
  bool _voiceActive = false;
  bool _disposed = false;
  bool _armed = false;

  SoundscapeStatus get status => _status;
  double get volume => _volume;
  bool get voiceActive => _voiceActive;
  bool get canPlay =>
      available &&
      !_voiceActive &&
      !_disposed &&
      _status != SoundscapeStatus.failed;
  bool get mediaPlayAllowed => _armed && canPlay;

  Future<void> play() async {
    if (!canPlay || _wantsPlayback) return;
    final revision = ++_revision;
    _wantsPlayback = true;
    _armed = true;
    _status = SoundscapeStatus.loading;
    notifyListeners();
    try {
      await _pendingSilence;
      if (!_current(revision)) return;
      await (_preparation ??= _output.prepare());
      if (!_current(revision)) return;
      await _output.setVolume(_volume);
      if (!_current(revision)) return;
      await _output.start();
    } catch (_) {
      if (_current(revision)) _fail();
    }
  }

  Future<bool> pause() {
    if (_disposed) return Future.value(false);
    ++_revision;
    _wantsPlayback = false;
    return _pendingSilence = _silence(stop: false);
  }

  Future<bool> _silence({required bool stop}) async {
    final revision = _revision;
    try {
      if (stop) {
        await _output.stop();
      } else {
        await _output.pause();
      }
      if (_disposed) return false;
      if (revision != _revision) return true;
      if (_status != SoundscapeStatus.off &&
          _status != SoundscapeStatus.failed) {
        _status = stop ? SoundscapeStatus.off : SoundscapeStatus.paused;
      }
      notifyListeners();
      return true;
    } catch (_) {
      _fail();
      return false;
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    ++_revision;
    _wantsPlayback = false;
    _armed = false;
    await (_pendingSilence = _silence(stop: true));
  }

  Future<void> setVolume(double value) async {
    if (_disposed || !value.isFinite) return;
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
    try {
      await _output.setVolume(_volume);
    } catch (_) {
      _fail();
    }
  }

  /// Must finish before microphone initialization/listening, not after it.
  Future<void> pauseForVoice() async {
    if (_disposed) throw StateError('Sound is disposed');
    _voiceActive = true;
    notifyListeners();
    if (!await pause()) throw StateError('Sound could not be paused');
  }

  void releaseVoice() {
    if (_disposed || !_voiceActive) return;
    _voiceActive = false;
    notifyListeners(); // Deliberately never resume sound automatically.
  }

  bool _current(int revision) =>
      !_disposed && revision == _revision && _wantsPlayback && !_voiceActive;

  void _fail() {
    if (_disposed || _status == SoundscapeStatus.failed) return;
    ++_revision;
    _wantsPlayback = false;
    _armed = false;
    _status = SoundscapeStatus.failed;
    notifyListeners();
    _pendingSilence = _output
        .stop()
        .then((_) => true)
        .catchError((Object _) => false);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_revision;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_output.dispose().catchError((Object _) {}));
    super.dispose();
  }
}

/// Disabled builds and a failed platform setup stay silent and usable.
class UnavailableSoundscapeOutput implements SoundscapeOutput {
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<void> get interruptions => const Stream.empty();
  @override
  Stream<Object> get errors => const Stream.empty();
  @override
  Future<void> prepare() async => throw StateError('Sound unavailable');
  @override
  Future<void> start() async => throw StateError('Sound unavailable');
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double value) async {}
  @override
  Future<void> dispose() async {}
}
