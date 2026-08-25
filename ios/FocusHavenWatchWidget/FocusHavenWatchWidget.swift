import SwiftUI
import WidgetKit

struct FocusHavenWatchComplicationEntry: TimelineEntry {
  let date: Date
  let content: SystemFocusWatchComplicationContent?
}

struct FocusHavenWatchComplicationProvider: TimelineProvider {
  private let store = SystemFocusWatchSnapshotStore()

  func placeholder(in context: Context) -> FocusHavenWatchComplicationEntry {
    FocusHavenWatchComplicationEntry(date: Date(), content: placeholderContent)
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (FocusHavenWatchComplicationEntry) -> Void
  ) {
    completion(entry(at: Date()))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<FocusHavenWatchComplicationEntry>) -> Void
  ) {
    let now = Date()
    let entry = entry(at: now)
    let policy: TimelineReloadPolicy
    if let deadline = entry.content?.timelineReloadDate, deadline > now {
      policy = .after(deadline)
    } else {
      policy = .never
    }
    completion(Timeline(entries: [entry], policy: policy))
  }

  private func entry(at date: Date) -> FocusHavenWatchComplicationEntry {
    FocusHavenWatchComplicationEntry(
      date: date,
      content: store.load().map {
        SystemFocusWatchComplicationContent(snapshot: $0, at: date)
      }
    )
  }

  private var placeholderContent: SystemFocusWatchComplicationContent? {
    let generatedAt = Date(timeIntervalSince1970: 1_787_002_400)
    let snapshot = SystemFocusWatchSnapshot(
      session: .focus,
      activity: .ready,
      secondsRemaining: 25 * 60,
      totalSessionSeconds: 25 * 60,
      generatedAt: generatedAt,
      endsAt: nil
    )
    return SystemFocusWatchComplicationContent(snapshot: snapshot, at: generatedAt)
  }
}

struct FocusHavenWatchComplicationView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FocusHavenWatchComplicationEntry

  @ViewBuilder
  var body: some View {
    if let content = entry.content {
      availableView(content)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilitySummary)
        .containerBackground(.clear, for: .widget)
    } else {
      unavailableView
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "FocusHaven. Open FocusHaven on your Apple Watch to sync the private timer."
        )
        .containerBackground(.clear, for: .widget)
    }
  }

  @ViewBuilder
  private func availableView(_ content: SystemFocusWatchComplicationContent) -> some View {
    switch family {
    case .accessoryInline:
      Label {
        inlineTimerText(content)
      } icon: {
        Image(systemName: icon(for: content.session))
      }
      .lineLimit(1)
    case .accessoryCircular:
      Gauge(value: content.progress) {
        Image(systemName: icon(for: content.session))
      } currentValueLabel: {
        complicationTimerText(content)
          .font(.caption2.weight(.bold))
          .minimumScaleFactor(0.6)
      }
      .gaugeStyle(.accessoryCircular)
      .widgetAccentable()
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 3) {
          Label(content.session.title, systemImage: icon(for: content.session))
            .font(.caption.weight(.semibold))
          Spacer(minLength: 2)
          Text(content.activity.title)
            .font(.caption2)
            .lineLimit(1)
        }
        complicationTimerText(content)
          .font(.headline.monospacedDigit().weight(.bold))
          .minimumScaleFactor(0.65)
          .lineLimit(1)
        ProgressView(value: content.progress)
          .widgetAccentable()
      }
    case .accessoryCorner:
      Gauge(value: content.progress) {
        Image(systemName: icon(for: content.session))
      } currentValueLabel: {
        complicationTimerText(content)
          .font(.caption2.weight(.bold))
          .minimumScaleFactor(0.55)
      }
      .gaugeStyle(.accessoryCircular)
      .widgetAccentable()
      .widgetLabel {
        Text(content.session.title)
      }
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private var unavailableView: some View {
    switch family {
    case .accessoryInline:
      Label("Open FocusHaven", systemImage: "timer")
    case .accessoryCircular, .accessoryCorner:
      Image(systemName: "timer")
        .font(.title3)
        .widgetAccentable()
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label("FocusHaven", systemImage: "timer")
          .font(.caption.weight(.semibold))
        Text("Open the Watch app to sync your private timer.")
          .font(.caption2)
          .lineLimit(2)
      }
    default:
      EmptyView()
    }
  }

  private func inlineTimerText(_ content: SystemFocusWatchComplicationContent) -> Text {
    if let deadline = content.endsAt, deadline > entry.date {
      return Text("\(content.session.title) ") + Text(deadline, style: .timer)
    }
    return Text("\(content.session.title) \(content.clockText)")
  }

  @ViewBuilder
  private func complicationTimerText(_ content: SystemFocusWatchComplicationContent) -> some View {
    if let deadline = content.endsAt, deadline > entry.date {
      Text(deadline, style: .timer)
        .monospacedDigit()
    } else {
      Text(content.compactDurationText)
        .monospacedDigit()
    }
  }

  private func icon(for session: SystemFocusWatchSession) -> String {
    switch session {
    case .focus: return "moon.stars.fill"
    case .shortBreak, .longBreak: return "cup.and.saucer.fill"
    }
  }
}

@main
struct FocusHavenWatchComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: SystemFocusWatchComplicationContent.widgetKind,
      provider: FocusHavenWatchComplicationProvider()
    ) { entry in
      FocusHavenWatchComplicationView(entry: entry)
    }
    .configurationDisplayName("FocusHaven Timer")
    .description("See the current private focus or break timer at a glance.")
    .supportedFamilies([
      .accessoryInline,
      .accessoryCircular,
      .accessoryRectangular,
      .accessoryCorner,
    ])
  }
}
