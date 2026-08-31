import '../services/focus_queue_service.dart';
import '../services/timer_service.dart';

enum HavenLoopPhase { ready, running, paused, completed, betweenSessions }

class HavenLoopState {
  const HavenLoopState({
    required this.selectedItem,
    required this.phase,
    required this.canResolveCompletion,
    required this.isInitialized,
  });

  const HavenLoopState.empty()
    : selectedItem = null,
      phase = HavenLoopPhase.betweenSessions,
      canResolveCompletion = false,
      isInitialized = false;

  final FocusQueueItem? selectedItem;
  final HavenLoopPhase phase;
  final bool canResolveCompletion;
  final bool isInitialized;

  String? get selectedItemId => selectedItem?.id;
  bool get hasSelectedTask => selectedItem != null;

  static HavenLoopPhase phaseFor(TimerService timer) {
    if (timer.sessionType != SessionType.focus) {
      return HavenLoopPhase.betweenSessions;
    }
    if (timer.isComplete) return HavenLoopPhase.completed;
    if (timer.isRunning) return HavenLoopPhase.running;
    if (timer.activeFocusFocusedSeconds > 0 || timer.hasPendingResume) {
      return HavenLoopPhase.paused;
    }
    return HavenLoopPhase.ready;
  }

  @override
  bool operator ==(Object other) =>
      other is HavenLoopState &&
      other.selectedItem?.id == selectedItem?.id &&
      other.selectedItem?.title == selectedItem?.title &&
      other.phase == phase &&
      other.canResolveCompletion == canResolveCompletion &&
      other.isInitialized == isInitialized;

  @override
  int get hashCode => Object.hash(
    selectedItem?.id,
    selectedItem?.title,
    phase,
    canResolveCompletion,
    isInitialized,
  );
}
