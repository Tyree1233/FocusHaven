import '../models/system_focus_snapshot.dart';
import 'timer_service.dart';

/// Builds the one-way, text-free state shared with trusted system surfaces.
///
/// This service does not persist state, invoke a platform channel, or mutate
/// the timer. Platform-specific command routing will remain a separate layer.
class SystemFocusSurfaceService {
  const SystemFocusSurfaceService();

  SystemFocusSnapshot createSnapshot({
    required SessionType sessionType,
    required bool isRunning,
    required bool isComplete,
    required bool hasPendingResume,
    required int secondsRemaining,
    required int totalSessionSeconds,
    required DateTime generatedAt,
  }) {
    if (isRunning && (isComplete || hasPendingResume)) {
      throw ArgumentError('The system surface requires a valid timer state.');
    }
    if (isComplete && hasPendingResume) {
      throw ArgumentError('A completed timer cannot also await a resume.');
    }

    final activity = switch ((
      isRunning,
      isComplete,
      hasPendingResume,
      secondsRemaining < totalSessionSeconds,
    )) {
      (true, _, _, _) => SystemFocusActivity.running,
      (_, true, _, _) => SystemFocusActivity.completed,
      (_, _, true, _) => SystemFocusActivity.pendingResume,
      (_, _, _, true) => SystemFocusActivity.paused,
      _ => SystemFocusActivity.ready,
    };
    final utcGeneratedAt = generatedAt.toUtc();

    return SystemFocusSnapshot(
      session: switch (sessionType) {
        SessionType.focus => SystemFocusSession.focus,
        SessionType.shortBreak => SystemFocusSession.shortBreak,
        SessionType.longBreak => SystemFocusSession.longBreak,
      },
      activity: activity,
      secondsRemaining: secondsRemaining,
      totalSessionSeconds: totalSessionSeconds,
      generatedAt: utcGeneratedAt,
      endsAt: activity == SystemFocusActivity.running
          ? utcGeneratedAt.add(Duration(seconds: secondsRemaining))
          : null,
    );
  }
}
