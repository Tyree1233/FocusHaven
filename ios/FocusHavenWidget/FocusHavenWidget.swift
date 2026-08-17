import SwiftUI
import WidgetKit

struct FocusHavenWidgetEntry: TimelineEntry {
  let date: Date
  let content: SystemFocusWidgetContent?
  let controlToken: String?
}

struct FocusHavenWidgetProvider: TimelineProvider {
  private let store = SystemFocusSnapshotStore()

  func placeholder(in context: Context) -> FocusHavenWidgetEntry {
    FocusHavenWidgetEntry(
      date: Date(),
      content: Self.placeholderContent,
      controlToken: nil
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (FocusHavenWidgetEntry) -> Void
  ) {
    completion(entry(at: Date()))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<FocusHavenWidgetEntry>) -> Void
  ) {
    let now = Date()
    let entry = entry(at: now)
    let policy: TimelineReloadPolicy
    if let deadline = entry.content?.endsAt {
      policy = .after(deadline)
    } else {
      policy = .never
    }
    completion(Timeline(entries: [entry], policy: policy))
  }

  private func entry(at date: Date) -> FocusHavenWidgetEntry {
    FocusHavenWidgetEntry(
      date: date,
      content: SystemFocusWidgetContent.fromSnapshot(store.load(), now: date),
      controlToken: store.loadControlToken()
    )
  }

  private static let placeholderContent = SystemFocusWidgetContent(
    session: .focus,
    activity: .ready,
    secondsRemaining: 25 * 60,
    totalSessionSeconds: 25 * 60,
    snapshotGeneratedAt: "2026-08-16T21:00:00.000Z",
    endsAt: nil,
    availableActions: [.start]
  )
}

struct FocusHavenWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FocusHavenWidgetEntry

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.09, green: 0.18, blue: 0.31), Color(red: 0.20, green: 0.38, blue: 0.49)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      if let content = entry.content {
        availableView(content)
      } else {
        unavailableView
      }
    }
    .foregroundColor(.white)
  }

  private func availableView(_ content: SystemFocusWidgetContent) -> some View {
    VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
      HStack {
        Label(content.session.title, systemImage: icon(for: content.session))
          .font(.caption.weight(.semibold))
          .lineLimit(1)
        Spacer(minLength: 4)
        Circle()
          .fill(content.activity == .running ? Color.green : Color.white.opacity(0.55))
          .frame(width: 8, height: 8)
          .accessibilityHidden(true)
      }

      Spacer(minLength: 2)
      countdown(content)
      Text(content.activity.title)
        .font(.caption)
        .foregroundColor(.white.opacity(0.82))
        .lineLimit(1)
      ProgressView(value: content.progress)
        .tint(.white)
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(Int((content.progress * 100).rounded())) percent")
      if family == .systemMedium {
        controls(content)
      }
    }
    .padding(family == .systemSmall ? 14 : 16)
    .accessibilityElement(children: .combine)
  }

  private var unavailableView: some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemName: "timer")
        .font(.title2)
      Text("Open FocusHaven")
        .font(.headline)
      Text("Your private timer will appear here after the app is ready.")
        .font(.caption)
        .foregroundColor(.white.opacity(0.82))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(16)
  }

  @ViewBuilder
  private func countdown(_ content: SystemFocusWidgetContent) -> some View {
    if let deadline = content.endsAt, deadline > entry.date {
      Text(deadline, style: .timer)
        .monospacedDigit()
        .font(.system(size: family == .systemSmall ? 31 : 36, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.75)
        .lineLimit(1)
    } else {
      Text(Self.durationText(content.secondsRemaining))
        .monospacedDigit()
        .font(.system(size: family == .systemSmall ? 31 : 36, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.75)
        .lineLimit(1)
    }
  }

  private func icon(for session: SystemFocusWidgetSession) -> String {
    switch session {
    case .focus: return "timer"
    case .shortBreak: return "cup.and.saucer.fill"
    case .longBreak: return "moon.stars.fill"
    }
  }

  @ViewBuilder
  private func controls(_ content: SystemFocusWidgetContent) -> some View {
    if let token = entry.controlToken,
      let primary = primaryAction(content.availableActions),
      let primaryURL = commandURL(primary, content: content, token: token)
    {
      HStack(spacing: 8) {
        commandLink(primary, url: primaryURL, prominent: true)
        if let secondary = secondaryAction(content.availableActions),
          let secondaryURL = commandURL(secondary, content: content, token: token)
        {
          commandLink(secondary, url: secondaryURL, prominent: false)
        }
      }
    }
  }

  private func commandLink(
    _ action: SystemFocusWidgetAction,
    url: URL,
    prominent: Bool
  ) -> some View {
    Link(destination: url) {
      Text(action.title)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(prominent ? Color.white : Color.white.opacity(0.16))
        .foregroundColor(prominent ? Color(red: 0.09, green: 0.18, blue: 0.31) : .white)
        .clipShape(Capsule())
    }
    .accessibilityLabel("\(action.title) FocusHaven timer")
  }

  private func commandURL(
    _ action: SystemFocusWidgetAction,
    content: SystemFocusWidgetContent,
    token: String
  ) -> URL? {
    var components = URLComponents()
    components.scheme = "focushaven"
    components.host = "system-focus-command"
    components.queryItems = [
      URLQueryItem(name: "action", value: action.rawValue),
      URLQueryItem(name: "snapshotGeneratedAt", value: content.snapshotGeneratedAt),
      URLQueryItem(name: "controlToken", value: token),
    ]
    return components.url
  }

  private func primaryAction(
    _ actions: Set<SystemFocusWidgetAction>
  ) -> SystemFocusWidgetAction? {
    for action in [
      SystemFocusWidgetAction.start,
      .pause,
      .resume,
      .beginNextSession,
    ] where actions.contains(action) {
      return action
    }
    return nil
  }

  private func secondaryAction(
    _ actions: Set<SystemFocusWidgetAction>
  ) -> SystemFocusWidgetAction? {
    if actions.contains(.reset) { return .reset }
    if actions.contains(.discardPending) { return .discardPending }
    return nil
  }

  private static func durationText(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    return String(format: "%d:%02d", minutes, remainder)
  }
}

@main
struct FocusHavenFocusWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: SystemFocusSnapshotStore.widgetKind,
      provider: FocusHavenWidgetProvider()
    ) { entry in
      FocusHavenWidgetView(entry: entry)
    }
    .configurationDisplayName("FocusHaven Timer")
    .description("See your current private focus or break timer at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
