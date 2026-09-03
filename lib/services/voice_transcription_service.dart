import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceTranscriptionStatus {
  idle,
  preparing,
  listening,
  stopping,
  unavailable,
  permissionDenied,
  failed,
}

enum VoiceTranscriptionPurpose { coach, havenAction }

/// Stable presentation reasons for a voice-transcription notice.
///
/// Widgets localize these values at the active presentation boundary. The
/// service retains its English [notice] compatibility getter for existing
/// diagnostics and tests, but production UI must use [noticeCode] instead of
/// treating service-owned English text as localized presentation copy.
enum VoiceTranscriptionNotice {
  recognitionUnavailableOnDevice,
  recognitionLocaleUnsupported,
  accessNotGranted,
  recognitionDidNotStart,
  transcriptionCouldNotStart,
  stoppedUnexpectedly,
  recognitionUnavailableNow,
  stoppedReviewOrRetry,
}

typedef VoiceRecognitionResultCallback =
    void Function(String transcript, bool isFinal);
typedef VoiceRecognitionStatusCallback = void Function(String status);
typedef VoiceRecognitionErrorCallback =
    void Function(String errorCode, bool isPermanent);

/// Narrow platform seam around the speech recognizer.
///
/// Keeping this interface smaller than the plugin API makes it possible to
/// prove that FocusHaven requests access only after an explicit user action
/// and that recognized text never bypasses the active surface's editable
/// draft.
abstract interface class VoiceRecognitionAdapter {
  bool get isListening;

  Future<bool> get hasPermission;

  Future<bool> initialize({
    required VoiceRecognitionStatusCallback onStatus,
    required VoiceRecognitionErrorCallback onError,
  });

  Future<void> listen({
    required String localeId,
    required VoiceRecognitionResultCallback onResult,
  });

  Future<void> stop();

  Future<void> cancel();
}

class SpeechToTextVoiceRecognitionAdapter implements VoiceRecognitionAdapter {
  SpeechToTextVoiceRecognitionAdapter({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;

  @override
  bool get isListening => _speechToText.isListening;

  @override
  Future<bool> get hasPermission => _speechToText.hasPermission;

  @override
  Future<bool> initialize({
    required VoiceRecognitionStatusCallback onStatus,
    required VoiceRecognitionErrorCallback onError,
  }) {
    return _speechToText.initialize(
      onStatus: onStatus,
      onError: (SpeechRecognitionError error) {
        onError(error.errorMsg, error.permanent);
      },
      debugLogging: false,
    );
  }

  @override
  Future<void> listen({
    required String localeId,
    required VoiceRecognitionResultCallback onResult,
  }) async {
    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        onDevice: false,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 45),
        localeId: localeId,
      ),
    );
  }

  @override
  Future<void> stop() => _speechToText.stop();

  @override
  Future<void> cancel() => _speechToText.cancel();
}

/// Session-memory-only owner for optional FocusHaven voice transcription.
///
/// This service never starts itself, stores audio, persists a transcript, or
/// sends text to Focus Coach or the Haven Action Engine. Its only output is an
/// editable in-memory draft that an active sheet may display after a user
/// explicitly taps the microphone control.
class VoiceTranscriptionService extends ChangeNotifier {
  VoiceTranscriptionService({VoiceRecognitionAdapter? adapter})
    : _adapter = adapter ?? SpeechToTextVoiceRecognitionAdapter();

  final VoiceRecognitionAdapter _adapter;

  static const supportedLocaleIds = <String>{'en', 'es'};

  VoiceTranscriptionStatus _status = VoiceTranscriptionStatus.idle;
  String _transcript = '';
  VoiceTranscriptionNotice? _noticeCode;
  bool _isFinal = false;
  bool _isInitialized = false;
  final Set<VoiceTranscriptionPurpose> _acknowledgedDisclosures = {};
  bool _acceptPlatformCallbacks = false;
  bool _disposed = false;
  int _operationRevision = 0;

  VoiceTranscriptionStatus get status => _status;
  String get transcript => _transcript;
  VoiceTranscriptionNotice? get noticeCode => _noticeCode;
  String? get notice => switch (_noticeCode) {
    VoiceTranscriptionNotice.recognitionUnavailableOnDevice =>
      'Speech recognition is unavailable on this device.',
    VoiceTranscriptionNotice.recognitionLocaleUnsupported =>
      'Voice transcription is not available for this language. You can keep typing instead.',
    VoiceTranscriptionNotice.accessNotGranted =>
      'Microphone or speech-recognition access was not granted. You can keep typing instead.',
    VoiceTranscriptionNotice.recognitionDidNotStart =>
      'Speech recognition did not start. You can keep typing.',
    VoiceTranscriptionNotice.transcriptionCouldNotStart =>
      'Voice transcription could not start. You can keep typing.',
    VoiceTranscriptionNotice.stoppedUnexpectedly =>
      'Voice transcription stopped unexpectedly. Review the draft before sending.',
    VoiceTranscriptionNotice.recognitionUnavailableNow =>
      'Speech recognition is unavailable right now. You can keep typing instead.',
    VoiceTranscriptionNotice.stoppedReviewOrRetry =>
      'Voice transcription stopped. Review the draft or try again.',
    null => null,
  };
  bool get isFinal => _isFinal;
  bool get disclosureAcknowledged =>
      disclosureAcknowledgedFor(VoiceTranscriptionPurpose.coach);
  bool get isListening => _status == VoiceTranscriptionStatus.listening;
  bool get isBusy =>
      _status == VoiceTranscriptionStatus.preparing ||
      _status == VoiceTranscriptionStatus.stopping;

  bool disclosureAcknowledgedFor(VoiceTranscriptionPurpose purpose) =>
      _acknowledgedDisclosures.contains(purpose);

  void acknowledgeDisclosure([
    VoiceTranscriptionPurpose purpose = VoiceTranscriptionPurpose.coach,
  ]) {
    _acknowledgedDisclosures.add(purpose);
  }

  Future<bool> start({
    required String localeId,
    VoiceTranscriptionPurpose purpose = VoiceTranscriptionPurpose.coach,
  }) async {
    if (!disclosureAcknowledgedFor(purpose) || isListening || isBusy) {
      return false;
    }

    final supportedLocaleId = _supportedLocaleId(localeId);
    if (supportedLocaleId == null) {
      _transcript = '';
      _isFinal = false;
      _noticeCode = VoiceTranscriptionNotice.recognitionLocaleUnsupported;
      _acceptPlatformCallbacks = false;
      _setStatus(VoiceTranscriptionStatus.unavailable);
      return false;
    }

    final operationRevision = ++_operationRevision;
    _acceptPlatformCallbacks = true;
    _transcript = '';
    _isFinal = false;
    _noticeCode = null;
    _setStatus(VoiceTranscriptionStatus.preparing);

    try {
      if (!_isInitialized) {
        final initialized = await _adapter.initialize(
          onStatus: _handlePlatformStatus,
          onError: _handlePlatformError,
        );
        if (!_isCurrentOperation(operationRevision)) return false;
        if (!initialized) {
          final permitted = await _adapter.hasPermission;
          _noticeCode = permitted
              ? VoiceTranscriptionNotice.recognitionUnavailableOnDevice
              : VoiceTranscriptionNotice.accessNotGranted;
          _setStatus(
            permitted
                ? VoiceTranscriptionStatus.unavailable
                : VoiceTranscriptionStatus.permissionDenied,
          );
          _acceptPlatformCallbacks = false;
          return false;
        }
        _isInitialized = true;
      }

      if (!_isCurrentOperation(operationRevision)) return false;
      await _adapter.listen(
        localeId: supportedLocaleId,
        onResult: _handleResult,
      );
      if (!_isCurrentOperation(operationRevision)) {
        await _cancelAdapterBestEffort();
        return false;
      }
      if (!_adapter.isListening) {
        _noticeCode = VoiceTranscriptionNotice.recognitionDidNotStart;
        _setStatus(VoiceTranscriptionStatus.failed);
        _acceptPlatformCallbacks = false;
        return false;
      }
      _setStatus(VoiceTranscriptionStatus.listening);
      return true;
    } catch (_) {
      if (!_isCurrentOperation(operationRevision)) return false;
      _noticeCode = VoiceTranscriptionNotice.transcriptionCouldNotStart;
      _setStatus(VoiceTranscriptionStatus.failed);
      _acceptPlatformCallbacks = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (!isListening && !_adapter.isListening) return;
    _setStatus(VoiceTranscriptionStatus.stopping);
    try {
      await _adapter.stop();
    } catch (_) {
      _noticeCode = VoiceTranscriptionNotice.stoppedUnexpectedly;
    } finally {
      _acceptPlatformCallbacks = false;
      _setStatus(VoiceTranscriptionStatus.idle);
    }
  }

  Future<void> cancel() async {
    _operationRevision += 1;
    _acceptPlatformCallbacks = false;
    if (_adapter.isListening || isListening || isBusy) {
      await _cancelAdapterBestEffort();
    }
    _transcript = '';
    _isFinal = false;
    _noticeCode = null;
    _setStatus(VoiceTranscriptionStatus.idle);
  }

  void dismissNotice() {
    if (_noticeCode == null) return;
    _noticeCode = null;
    if (_status != VoiceTranscriptionStatus.listening) {
      _status = VoiceTranscriptionStatus.idle;
    }
    _notifySafely();
  }

  void _handleResult(String transcript, bool isFinal) {
    if (_disposed || !_acceptPlatformCallbacks) return;
    _transcript = transcript.trim();
    _isFinal = isFinal;
    _notifySafely();
  }

  void _handlePlatformStatus(String status) {
    if (_disposed || !_acceptPlatformCallbacks) return;
    if (status == 'listening') {
      _setStatus(VoiceTranscriptionStatus.listening);
    } else if (status == 'done' || status == 'notListening') {
      _setStatus(VoiceTranscriptionStatus.idle);
      _acceptPlatformCallbacks = false;
    }
  }

  void _handlePlatformError(String errorCode, bool isPermanent) {
    if (_disposed || !_acceptPlatformCallbacks) return;
    _acceptPlatformCallbacks = false;
    unawaited(_cancelAdapterBestEffort());
    final normalized = errorCode.toLowerCase();
    final denied =
        normalized.contains('permission') ||
        normalized.contains('not_allowed') ||
        normalized.contains('notallowed');
    _noticeCode = denied
        ? VoiceTranscriptionNotice.accessNotGranted
        : isPermanent
        ? VoiceTranscriptionNotice.recognitionUnavailableNow
        : VoiceTranscriptionNotice.stoppedReviewOrRetry;
    _setStatus(
      denied
          ? VoiceTranscriptionStatus.permissionDenied
          : VoiceTranscriptionStatus.failed,
    );
  }

  bool _isCurrentOperation(int revision) =>
      !_disposed && revision == _operationRevision;

  static String? _supportedLocaleId(String localeId) {
    final normalized = localeId.trim().toLowerCase();
    return supportedLocaleIds.contains(normalized) ? normalized : null;
  }

  Future<void> _cancelAdapterBestEffort() async {
    try {
      await _adapter.cancel();
    } catch (_) {
      // Cancellation is best-effort during a sheet close or discarded draft.
    }
  }

  void _setStatus(VoiceTranscriptionStatus value) {
    if (_disposed) return;
    _status = value;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _operationRevision += 1;
    _acceptPlatformCallbacks = false;
    _disposed = true;
    if (_adapter.isListening) unawaited(_cancelAdapterBestEffort());
    _transcript = '';
    super.dispose();
  }
}
