import Foundation

/// A glanceable, text-free projection of the validated Watch snapshot.
///
/// This type deliberately cannot represent tasks, reflections, moods, history,
/// coaching content, account identifiers, commands, or command capabilities.
struct SystemFocusWatchComplicationContent: Equatable {
  static let widgetKind = "FocusHavenWatchComplication"

  let session: SystemFocusWatchSession
  let activity: SystemFocusWatchActivity
  let secondsRemaining: Int
  let totalSessionSeconds: Int
  let endsAt: Date?
  let accessibilitySummary: String

  init(snapshot: SystemFocusWatchSnapshot, at date: Date) {
    session = snapshot.session
    activity = snapshot.activity(at: date)
    secondsRemaining = snapshot.remainingSeconds(at: date)
    totalSessionSeconds = snapshot.totalSessionSeconds
    endsAt = activity == .running ? snapshot.endsAt : nil
    accessibilitySummary = snapshot.accessibilitySummary(at: date)
  }

  var progress: Double {
    Double(totalSessionSeconds - secondsRemaining) / Double(totalSessionSeconds)
  }

  var clockText: String {
    String(format: "%d:%02d", secondsRemaining / 60, secondsRemaining % 60)
  }

  var compactDurationText: String {
    if secondsRemaining >= 3_600 {
      let hours = secondsRemaining / 3_600
      let minutes = (secondsRemaining % 3_600) / 60
      return String(format: "%d:%02d", hours, minutes)
    }
    return clockText
  }

  var timelineReloadDate: Date? {
    endsAt
  }
}
