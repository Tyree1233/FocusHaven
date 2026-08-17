import SwiftUI

@main
struct FocusHavenWatchApp: App {
  @StateObject private var model = SystemFocusWatchModel()

  var body: some Scene {
    WindowGroup {
      FocusHavenWatchView(model: model)
    }
  }
}

struct FocusHavenWatchView: View {
  @ObservedObject var model: SystemFocusWatchModel

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      if let snapshot = model.snapshot {
        snapshotView(snapshot, at: context.date)
      } else {
        waitingView
      }
    }
  }

  private var waitingView: some View {
    VStack(spacing: 8) {
      Image(systemName: "moon.stars.fill")
        .font(.title2)
        .foregroundStyle(.indigo)
      Text("FocusHaven")
        .font(.headline)
      Text("Open FocusHaven on your iPhone to sync the timer.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .accessibilityElement(children: .combine)
  }

  private func snapshotView(
    _ snapshot: SystemFocusWatchSnapshot,
    at date: Date
  ) -> some View {
    let activity = snapshot.activity(at: date)
    let remaining = snapshot.remainingSeconds(at: date)
    return VStack(spacing: 6) {
      HStack(spacing: 5) {
        Image(systemName: snapshot.session == .focus ? "moon.stars.fill" : "cup.and.saucer.fill")
          .foregroundStyle(snapshot.session == .focus ? .indigo : .teal)
        Text(snapshot.session.title)
          .font(.headline)
      }
      Text(activity.title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(Self.durationText(remaining))
        .font(.system(.title, design: .rounded, weight: .semibold))
        .monospacedDigit()
      ProgressView(value: snapshot.progress(at: date))
        .tint(snapshot.session == .focus ? .indigo : .teal)
      Text("Private timer only")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(snapshot.session.title), \(activity.title), \(Self.accessibleDuration(remaining)) remaining"
    )
  }

  private static func durationText(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  private static func accessibleDuration(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    if remainder == 0 { return "\(minutes) minutes" }
    return "\(minutes) minutes, \(remainder) seconds"
  }
}
