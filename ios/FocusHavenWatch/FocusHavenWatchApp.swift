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
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var pendingDestructiveAction: SystemFocusWatchAction?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      if let snapshot = model.snapshot {
        snapshotView(snapshot, at: context.date)
      } else {
        waitingView
      }
    }
    .confirmationDialog(
      "Change this session?",
      isPresented: Binding(
        get: { pendingDestructiveAction != nil },
        set: { if !$0 { pendingDestructiveAction = nil } }
      ),
      presenting: pendingDestructiveAction
    ) { action in
      Button(action.title, role: .destructive) {
        model.send(action)
        pendingDestructiveAction = nil
      }
      Button("Cancel", role: .cancel) {
        pendingDestructiveAction = nil
      }
    } message: { action in
      Text("Confirm \(action.title.lowercased()) for the current timer.")
    }
  }

  private var waitingView: some View {
    ScrollView {
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
      .padding(dynamicTypeSize.isAccessibilitySize ? 6 : 12)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        "FocusHaven. Open FocusHaven on your iPhone to sync the timer."
      )
    }
  }

  private func snapshotView(
    _ snapshot: SystemFocusWatchSnapshot,
    at date: Date
  ) -> some View {
    let activity = snapshot.activity(at: date)
    let remaining = snapshot.remainingSeconds(at: date)
    let actions = activity == snapshot.activity ? snapshot.availableActions : []
    return ScrollView {
      VStack(spacing: 8) {
        VStack(spacing: 6) {
          sessionHeading(snapshot)
          Text(activity.title)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(Self.durationText(remaining))
            .font(.system(.title, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .minimumScaleFactor(0.65)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
          ProgressView(value: snapshot.progress(at: date))
            .tint(snapshot.session == .focus ? .indigo : .teal)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.accessibilitySummary(at: date))

        controls(actions)

        if let message = model.commandState.message {
          Text(message)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        } else {
          Text("Private timer only")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 4 : 8)
    }
  }

  @ViewBuilder
  private func sessionHeading(_ snapshot: SystemFocusWatchSnapshot) -> some View {
    if dynamicTypeSize.isAccessibilitySize {
      Text(snapshot.session.title)
        .font(.headline)
        .multilineTextAlignment(.center)
    } else {
      HStack(spacing: 5) {
        Image(
          systemName: snapshot.session == .focus
            ? "moon.stars.fill"
            : "cup.and.saucer.fill"
        )
        .foregroundStyle(snapshot.session == .focus ? .indigo : .teal)
        Text(snapshot.session.title)
          .font(.headline)
      }
    }
  }

  @ViewBuilder
  private func controls(_ actions: Set<SystemFocusWatchAction>) -> some View {
    if let primary = primaryAction(actions) {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(spacing: 4) {
          commandButton(primary, prominent: true)
          if let secondary = secondaryAction(actions) {
            commandButton(secondary, prominent: false)
          }
        }
      } else {
        HStack(spacing: 6) {
          commandButton(primary, prominent: true)
          if let secondary = secondaryAction(actions) {
            commandButton(secondary, prominent: false)
          }
        }
      }
    }
  }

  private func commandButton(
    _ action: SystemFocusWatchAction,
    prominent: Bool
  ) -> some View {
    Button {
      if action == .reset || action == .discardPending {
        pendingDestructiveAction = action
      } else {
        model.send(action)
      }
    } label: {
      Text(action.title)
        .font(.caption.weight(.semibold))
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.borderedProminent)
    .tint(prominent ? .indigo : .gray)
    .disabled(!model.canSend(action))
    .accessibilityLabel(action.accessibilityLabel)
  }

  private func primaryAction(
    _ actions: Set<SystemFocusWatchAction>
  ) -> SystemFocusWatchAction? {
    for action in [
      SystemFocusWatchAction.start,
      .pause,
      .resume,
      .beginNextSession,
    ] where actions.contains(action) {
      return action
    }
    return nil
  }

  private func secondaryAction(
    _ actions: Set<SystemFocusWatchAction>
  ) -> SystemFocusWatchAction? {
    if actions.contains(.reset) { return .reset }
    if actions.contains(.discardPending) { return .discardPending }
    return nil
  }

  private static func durationText(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

}
