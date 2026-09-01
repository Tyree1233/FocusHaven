import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/services/voice_transcription_service.dart';

void main() {
  test('construction does not initialize or listen', () {
    final adapter = _FakeVoiceRecognitionAdapter();

    VoiceTranscriptionService(adapter: adapter);

    expect(adapter.initializeCalls, 0);
    expect(adapter.listenCalls, 0);
  });

  test('explicit disclosure is required before recognition starts', () async {
    final adapter = _FakeVoiceRecognitionAdapter();
    final service = VoiceTranscriptionService(adapter: adapter);

    expect(await service.start(), isFalse);
    expect(service.status, VoiceTranscriptionStatus.idle);
    expect(adapter.initializeCalls, 0);
    expect(adapter.listenCalls, 0);
  });

  test('Coach and Haven actions require separate disclosures', () async {
    final adapter = _FakeVoiceRecognitionAdapter();
    final service = VoiceTranscriptionService(adapter: adapter)
      ..acknowledgeDisclosure();

    expect(service.disclosureAcknowledged, isTrue);
    expect(
      service.disclosureAcknowledgedFor(VoiceTranscriptionPurpose.havenAction),
      isFalse,
    );
    expect(
      await service.start(purpose: VoiceTranscriptionPurpose.havenAction),
      isFalse,
    );
    expect(adapter.initializeCalls, 0);

    service.acknowledgeDisclosure(VoiceTranscriptionPurpose.havenAction);
    expect(
      await service.start(purpose: VoiceTranscriptionPurpose.havenAction),
      isTrue,
    );
    await service.cancel();
  });

  test(
    'starts once, streams an in-memory transcript, and stops safely',
    () async {
      final adapter = _FakeVoiceRecognitionAdapter();
      final service = VoiceTranscriptionService(adapter: adapter)
        ..acknowledgeDisclosure();

      expect(await service.start(), isTrue);
      expect(service.status, VoiceTranscriptionStatus.listening);
      expect(adapter.initializeCalls, 1);
      expect(adapter.listenCalls, 1);

      adapter.emitResult('help me plan the next step', isFinal: false);
      expect(service.transcript, 'help me plan the next step');
      expect(service.isFinal, isFalse);

      adapter.emitResult('help me plan the next step', isFinal: true);
      expect(service.isFinal, isTrue);

      await service.stop();
      expect(service.status, VoiceTranscriptionStatus.idle);
      expect(service.transcript, 'help me plan the next step');
      expect(adapter.stopCalls, 1);

      expect(await service.start(), isTrue);
      expect(adapter.initializeCalls, 1);
      expect(adapter.listenCalls, 2);
    },
  );

  test(
    'discard cancels recognition and removes the session transcript',
    () async {
      final adapter = _FakeVoiceRecognitionAdapter();
      final service = VoiceTranscriptionService(adapter: adapter)
        ..acknowledgeDisclosure();

      expect(await service.start(), isTrue);
      adapter.emitResult('private unfinished thought', isFinal: false);

      await service.cancel();

      expect(adapter.cancelCalls, 1);
      expect(service.status, VoiceTranscriptionStatus.idle);
      expect(service.transcript, isEmpty);
      expect(service.notice, isNull);
    },
  );

  test('a cancelled initialization cannot revive listening', () async {
    final initialization = Completer<bool>();
    final adapter = _FakeVoiceRecognitionAdapter(
      initialization: initialization.future,
    );
    final service = VoiceTranscriptionService(adapter: adapter)
      ..acknowledgeDisclosure();

    final starting = service.start();
    expect(service.status, VoiceTranscriptionStatus.preparing);

    await service.cancel();
    initialization.complete(true);

    expect(await starting, isFalse);
    expect(service.status, VoiceTranscriptionStatus.idle);
    expect(adapter.listenCalls, 0);
  });

  test(
    'permission denial stays contained and preserves typed fallback',
    () async {
      final adapter = _FakeVoiceRecognitionAdapter(
        initializeResult: false,
        permission: false,
      );
      final service = VoiceTranscriptionService(adapter: adapter)
        ..acknowledgeDisclosure();

      expect(await service.start(), isFalse);

      expect(service.status, VoiceTranscriptionStatus.permissionDenied);
      expect(service.noticeCode, VoiceTranscriptionNotice.accessNotGranted);
      expect(service.notice, contains('You can keep typing instead'));
      expect(adapter.listenCalls, 0);

      service.dismissNotice();
      expect(service.status, VoiceTranscriptionStatus.idle);
      expect(service.notice, isNull);
    },
  );

  test('platform errors expose no raw recognition details', () async {
    final adapter = _FakeVoiceRecognitionAdapter();
    final service = VoiceTranscriptionService(adapter: adapter)
      ..acknowledgeDisclosure();

    expect(await service.start(), isTrue);
    adapter.emitError('network_secret_vendor_detail', isPermanent: false);

    expect(service.status, VoiceTranscriptionStatus.failed);
    expect(service.noticeCode, VoiceTranscriptionNotice.stoppedReviewOrRetry);
    expect(
      service.notice,
      'Voice transcription stopped. Review the draft or try again.',
    );
    expect(service.notice, isNot(contains('network_secret_vendor_detail')));
    expect(adapter.cancelCalls, 1);
  });
}

class _FakeVoiceRecognitionAdapter implements VoiceRecognitionAdapter {
  _FakeVoiceRecognitionAdapter({
    this.initializeResult = true,
    this.permission = true,
    this.initialization,
  });

  final bool initializeResult;
  final bool permission;
  final Future<bool>? initialization;

  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool listening = false;
  VoiceRecognitionStatusCallback? _onStatus;
  VoiceRecognitionErrorCallback? _onError;
  VoiceRecognitionResultCallback? _onResult;

  @override
  bool get isListening => listening;

  @override
  Future<bool> get hasPermission async => permission;

  @override
  Future<bool> initialize({
    required VoiceRecognitionStatusCallback onStatus,
    required VoiceRecognitionErrorCallback onError,
  }) async {
    initializeCalls += 1;
    _onStatus = onStatus;
    _onError = onError;
    return initialization == null ? initializeResult : initialization!;
  }

  @override
  Future<void> listen({
    required VoiceRecognitionResultCallback onResult,
  }) async {
    listenCalls += 1;
    _onResult = onResult;
    listening = true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    listening = false;
  }

  void emitResult(String transcript, {required bool isFinal}) {
    _onResult?.call(transcript, isFinal);
  }

  void emitStatus(String status) {
    if (status == 'listening') listening = true;
    if (status == 'done' || status == 'notListening') listening = false;
    _onStatus?.call(status);
  }

  void emitError(String code, {required bool isPermanent}) {
    listening = false;
    _onError?.call(code, isPermanent);
  }
}
