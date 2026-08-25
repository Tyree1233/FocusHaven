import ActivityKit
import Foundation

protocol SystemFocusLiveActivityPublishing {
  func publish(snapshot: [String: Any])
}

final class SystemFocusUnavailableLiveActivityController: SystemFocusLiveActivityPublishing {
  func publish(snapshot: [String: Any]) {}
}

@available(iOS 16.1, *)
final class SystemFocusLiveActivityController: SystemFocusLiveActivityPublishing {
  private let lock = NSLock()
  private var pendingTask: Task<Void, Never>?

  func publish(snapshot: [String: Any]) {
    guard let content = SystemFocusWidgetContent.fromSnapshot(snapshot) else {
      return
    }
    let state = SystemFocusLiveActivityState(content: content)

    lock.lock()
    let previousTask = pendingTask
    let nextTask = Task {
      await previousTask?.value
      await Self.reconcile(state: state)
    }
    pendingTask = nextTask
    lock.unlock()
  }

  private static func reconcile(state: SystemFocusLiveActivityState) async {
    let activities = Activity<FocusHavenLiveActivityAttributes>.activities
    let current = activities.first

    for duplicate in activities.dropFirst() {
      await endImmediately(duplicate)
    }

    let operation = SystemFocusLiveActivityPolicy.operation(
      for: state.activity,
      hasExistingActivity: current != nil,
      activitiesEnabled: ActivityAuthorizationInfo().areActivitiesEnabled
    )

    switch operation {
    case .ignore:
      return
    case .start:
      await start(state: state)
    case .update:
      guard let current else { return }
      await update(current, state: state)
    case .endImmediately:
      guard let current else { return }
      await endImmediately(current)
    case .endWithFinalState:
      guard let current else { return }
      await endWithFinalState(current, state: state)
    }
  }

  private static func start(state: SystemFocusLiveActivityState) async {
    let attributes = FocusHavenLiveActivityAttributes(schemaVersion: 1)
    do {
      if #available(iOS 16.2, *) {
        _ = try Activity.request(
          attributes: attributes,
          content: activityContent(state),
          pushType: nil
        )
      } else {
        _ = try Activity.request(
          attributes: attributes,
          contentState: state,
          pushType: nil
        )
      }
    } catch {
      // The timer remains authoritative even when the system declines a surface.
    }
  }

  private static func update(
    _ activity: Activity<FocusHavenLiveActivityAttributes>,
    state: SystemFocusLiveActivityState
  ) async {
    if #available(iOS 16.2, *) {
      await activity.update(activityContent(state))
    } else {
      await activity.update(using: state)
    }
  }

  private static func endImmediately(
    _ activity: Activity<FocusHavenLiveActivityAttributes>
  ) async {
    if #available(iOS 16.2, *) {
      await activity.end(nil, dismissalPolicy: .immediate)
    } else {
      await activity.end(using: nil, dismissalPolicy: .immediate)
    }
  }

  private static func endWithFinalState(
    _ activity: Activity<FocusHavenLiveActivityAttributes>,
    state: SystemFocusLiveActivityState
  ) async {
    if #available(iOS 16.2, *) {
      await activity.end(activityContent(state), dismissalPolicy: .default)
    } else {
      await activity.end(using: state, dismissalPolicy: .default)
    }
  }

  @available(iOS 16.2, *)
  private static func activityContent(
    _ state: SystemFocusLiveActivityState
  ) -> ActivityContent<SystemFocusLiveActivityState> {
    ActivityContent(
      state: state,
      staleDate: state.staleDate,
      relevanceScore: state.activity == .running ? 1 : 0
    )
  }
}
