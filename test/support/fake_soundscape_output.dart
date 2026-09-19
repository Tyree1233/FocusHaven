import 'dart:async';
import 'package:focushaven/services/soundscape_controller.dart';

class FakeSoundscapeOutput implements SoundscapeOutput {
  final states = StreamController<bool>.broadcast(sync: true);
  final interrupted = StreamController<void>.broadcast(sync: true);
  final failures = StreamController<Object>.broadcast(sync: true);
  Completer<void>? preparation;
  Completer<void>? pausing;
  int prepares = 0;
  int starts = 0;
  int pauses = 0;
  int stops = 0;
  bool failPrepare = false;
  bool failPause = false;
  double volume = 0;
  bool disposed = false;
  @override
  Stream<bool> get playing => states.stream;
  @override
  Stream<void> get interruptions => interrupted.stream;
  @override
  Stream<Object> get errors => failures.stream;
  @override
  Future<void> prepare() async {
    prepares++;
    if (failPrepare) throw StateError('fixture');
    await preparation?.future;
  }

  @override
  Future<void> start() async {
    starts++;
    states.add(true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    if (failPause) throw StateError('fixture');
    await pausing?.future;
    states.add(false);
  }

  @override
  Future<void> stop() async {
    stops++;
    states.add(false);
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await states.close();
    await interrupted.close();
    await failures.close();
  }
}
