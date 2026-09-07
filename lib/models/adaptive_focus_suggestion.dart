import 'focus_forecast.dart';

enum AdaptiveFocusDirection { gentler, keepCurrent, roomToGrow }

enum AdaptiveFocusBreakDirection { keepCurrent, moreRecovery }

enum AdaptiveFocusBasis {
  explicitChoice,
  recoveryPriority,
  latestReflection,
  repeatedRhythm,
  currentBaseline,
}

enum AdaptiveFocusEvidenceStrength { limited, supported, reinforced }

/// One private, text-free, advisory preview for a possible later session.
///
/// The preview is rebuilt locally and owns no timer, schedule, or persistence
/// operation. Its values can be reviewed without applying them.
class AdaptiveFocusSuggestion {
  const AdaptiveFocusSuggestion({
    required this.currentFocusMinutes,
    required this.currentBreakMinutes,
    required this.suggestedFocusMinutes,
    required this.suggestedBreakMinutes,
    required this.direction,
    required this.breakDirection,
    required this.basis,
    required this.evidenceStrength,
    required this.relevantSignalCount,
    required this.usesRecoveryPattern,
    required this.usesLatestReflection,
    required this.usesRepeatedRhythm,
    required this.usesForecast,
    this.possibleWindow,
  });

  final int currentFocusMinutes;
  final int currentBreakMinutes;
  final int suggestedFocusMinutes;
  final int suggestedBreakMinutes;
  final AdaptiveFocusDirection direction;
  final AdaptiveFocusBreakDirection breakDirection;
  final AdaptiveFocusBasis basis;
  final AdaptiveFocusEvidenceStrength evidenceStrength;
  final int relevantSignalCount;
  final bool usesRecoveryPattern;
  final bool usesLatestReflection;
  final bool usesRepeatedRhythm;
  final bool usesForecast;
  final FocusForecastWindow? possibleWindow;

  bool get keepsCurrentFocus => suggestedFocusMinutes == currentFocusMinutes;
  bool get keepsCurrentBreak => suggestedBreakMinutes == currentBreakMinutes;
  bool get changesAnything => !keepsCurrentFocus || !keepsCurrentBreak;
  bool get isRecoveryLed => basis == AdaptiveFocusBasis.recoveryPriority;
  bool get preservesExplicitChoice =>
      basis == AdaptiveFocusBasis.explicitChoice;
  bool get hasPossibleWindow => possibleWindow != null;

  @override
  bool operator ==(Object other) =>
      other is AdaptiveFocusSuggestion &&
      other.currentFocusMinutes == currentFocusMinutes &&
      other.currentBreakMinutes == currentBreakMinutes &&
      other.suggestedFocusMinutes == suggestedFocusMinutes &&
      other.suggestedBreakMinutes == suggestedBreakMinutes &&
      other.direction == direction &&
      other.breakDirection == breakDirection &&
      other.basis == basis &&
      other.evidenceStrength == evidenceStrength &&
      other.relevantSignalCount == relevantSignalCount &&
      other.usesRecoveryPattern == usesRecoveryPattern &&
      other.usesLatestReflection == usesLatestReflection &&
      other.usesRepeatedRhythm == usesRepeatedRhythm &&
      other.usesForecast == usesForecast &&
      other.possibleWindow == possibleWindow;

  @override
  int get hashCode => Object.hash(
    currentFocusMinutes,
    currentBreakMinutes,
    suggestedFocusMinutes,
    suggestedBreakMinutes,
    direction,
    breakDirection,
    basis,
    evidenceStrength,
    relevantSignalCount,
    usesRecoveryPattern,
    usesLatestReflection,
    usesRepeatedRhythm,
    usesForecast,
    possibleWindow,
  );
}
