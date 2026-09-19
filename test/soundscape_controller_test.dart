import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/soundscape_controller.dart';
import 'support/fake_soundscape_output.dart';

void main() {
  late FakeSoundscapeOutput output;
  late SoundscapeController sound;
  setUp(() {
    output = FakeSoundscapeOutput();
    sound = SoundscapeController(output);
  });
  tearDown(() => sound.dispose());

  test('startup is silent and media controls cannot initiate first play', () {
    expect(sound.status, SoundscapeStatus.off);
    expect(sound.volume, 0.25);
    expect(sound.mediaPlayAllowed, isFalse);
    expect(output.prepares, 0);
    expect(output.starts, 0);
  });
  test('explicit play loads once, pause and resume reuse the asset', () async {
    await sound.play();
    expect(sound.status, SoundscapeStatus.playing);
    expect(output.volume, 0.25);
    await sound.pause();
    expect(sound.status, SoundscapeStatus.paused);
    await sound.play();
    expect(output.prepares, 1);
    expect(output.starts, 2);
  });
  test('repeated play does not create overlapping players', () async {
    await Future.wait([sound.play(), sound.play(), sound.play()]);
    expect(output.starts, 1);
    expect(output.prepares, 1);
  });
  test('pause during loading prevents delayed playback', () async {
    output.preparation = Completer<void>();
    final starting = sound.play();
    await Future<void>.delayed(Duration.zero);
    await sound.pause();
    output.preparation!.complete();
    await starting;
    expect(output.starts, 0);
    expect(sound.status, SoundscapeStatus.paused);
  });
  test('new play waits for an outstanding pause', () async {
    await sound.play();
    output.pausing = Completer<void>();
    final pausing = sound.pause();
    final starting = sound.play();
    await Future<void>.delayed(Duration.zero);
    expect(output.starts, 1);
    output.pausing!.complete();
    await pausing;
    await starting;
    expect(output.starts, 2);
    expect(sound.status, SoundscapeStatus.playing);
  });
  test('interruptions pause and never automatically resume', () async {
    await sound.play();
    output.interrupted.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(sound.status, SoundscapeStatus.paused);
    expect(output.starts, 1);
  });
  test(
    'voice blocks playback until released, without automatic resume',
    () async {
      await sound.play();
      await sound.pauseForVoice();
      await sound.play();
      expect(sound.voiceActive, isTrue);
      expect(sound.mediaPlayAllowed, isFalse);
      expect(output.starts, 1);
      sound.releaseVoice();
      expect(sound.status, SoundscapeStatus.paused);
      await sound.play();
      expect(output.starts, 2);
    },
  );
  test('a failed pause does not grant microphone clearance', () async {
    output.failPause = true;
    await expectLater(sound.pauseForVoice(), throwsStateError);
    expect(sound.status, SoundscapeStatus.failed);
  });
  test('stop disarms remote media play', () async {
    await sound.play();
    await sound.stop();
    expect(sound.status, SoundscapeStatus.off);
    expect(sound.mediaPlayAllowed, isFalse);
  });
  test('volume is finite and bounded', () async {
    await sound.setVolume(2);
    expect(output.volume, 1);
    await sound.setVolume(-1);
    expect(output.volume, 0);
    await sound.setVolume(double.nan);
    expect(sound.volume, 0);
  });
  test('load failure is contained and stops output', () async {
    output.failPrepare = true;
    await sound.play();
    expect(sound.status, SoundscapeStatus.failed);
    expect(output.starts, 0);
    expect(output.stops, 1);
  });
  test('asynchronous playback failure is contained', () async {
    await sound.play();
    output.failures.add(StateError('fixture'));
    expect(sound.status, SoundscapeStatus.failed);
    expect(output.stops, 1);
  });
  test('disposal cancels delayed play', () async {
    output.preparation = Completer<void>();
    final starting = sound.play();
    await Future<void>.delayed(Duration.zero);
    sound.dispose();
    output.preparation!.complete();
    await starting;
    expect(output.starts, 0);
    expect(output.disposed, isTrue);
  });
}
