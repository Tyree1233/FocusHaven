import '../services/voice_transcription_service.dart';
import 'app_localizations.dart';

/// Converts stable voice-service notice reasons into presentation-owned copy.
///
/// Keeping this mapping outside the service prevents platform recognition
/// state from depending on a widget context or a production locale.
String localizeVoiceTranscriptionNotice(
  AppLocalizations l10n,
  VoiceTranscriptionNotice notice,
) => switch (notice) {
  VoiceTranscriptionNotice.recognitionUnavailableOnDevice =>
    l10n.voiceRecognitionUnavailableOnDevice,
  VoiceTranscriptionNotice.accessNotGranted => l10n.voiceAccessNotGranted,
  VoiceTranscriptionNotice.recognitionDidNotStart =>
    l10n.voiceRecognitionDidNotStart,
  VoiceTranscriptionNotice.transcriptionCouldNotStart =>
    l10n.voiceTranscriptionCouldNotStart,
  VoiceTranscriptionNotice.stoppedUnexpectedly =>
    l10n.voiceTranscriptionStoppedUnexpectedly,
  VoiceTranscriptionNotice.recognitionUnavailableNow =>
    l10n.voiceRecognitionUnavailableNow,
  VoiceTranscriptionNotice.stoppedReviewOrRetry =>
    l10n.voiceTranscriptionStoppedReviewOrRetry,
};
