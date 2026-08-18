import Foundation

struct HavenWindowBusyInterval: Equatable {
  let startsAt: Date
  let endsAt: Date
}

enum HavenWindowAvailabilityPayloadError: Error {
  case invalidRange
}

/// The complete, text-free calendar availability contract returned to Flutter.
struct HavenWindowAvailabilityPayload {
  static let schemaVersion = 1
  static let maximumRange: TimeInterval = 36 * 60 * 60
  static let maximumBusyIntervals = 64

  let status: String
  let rangeStart: Date?
  let rangeEnd: Date?
  let busyIntervals: [HavenWindowBusyInterval]

  static func unavailable(status: String) -> HavenWindowAvailabilityPayload {
    HavenWindowAvailabilityPayload(
      status: status,
      rangeStart: nil,
      rangeEnd: nil,
      busyIntervals: []
    )
  }

  static func ready(
    rangeStart: Date,
    rangeEnd: Date,
    busyIntervals: [HavenWindowBusyInterval]
  ) throws -> HavenWindowAvailabilityPayload {
    let duration = rangeEnd.timeIntervalSince(rangeStart)
    guard duration > 0, duration <= maximumRange else {
      throw HavenWindowAvailabilityPayloadError.invalidRange
    }

    let bounded = busyIntervals.compactMap { interval -> HavenWindowBusyInterval? in
      let startsAt = max(interval.startsAt, rangeStart)
      let endsAt = min(interval.endsAt, rangeEnd)
      guard startsAt < endsAt else { return nil }
      return HavenWindowBusyInterval(startsAt: startsAt, endsAt: endsAt)
    }.sorted { lhs, rhs in
      if lhs.startsAt == rhs.startsAt {
        return lhs.endsAt < rhs.endsAt
      }
      return lhs.startsAt < rhs.startsAt
    }

    var merged: [HavenWindowBusyInterval] = []
    for interval in bounded {
      guard let previous = merged.last else {
        merged.append(interval)
        continue
      }
      if interval.startsAt <= previous.endsAt {
        merged[merged.count - 1] = HavenWindowBusyInterval(
          startsAt: previous.startsAt,
          endsAt: max(previous.endsAt, interval.endsAt)
        )
      } else {
        merged.append(interval)
      }
    }

    // Never truncate busy time into a false opening. An unusually fragmented
    // calendar fails closed by marking the bounded query range as busy.
    if merged.count > maximumBusyIntervals {
      merged = [HavenWindowBusyInterval(startsAt: rangeStart, endsAt: rangeEnd)]
    }

    return HavenWindowAvailabilityPayload(
      status: "ready",
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      busyIntervals: merged
    )
  }

  var dictionary: [String: Any] {
    guard status == "ready", let rangeStart, let rangeEnd else {
      return [
        "schemaVersion": Self.schemaVersion,
        "status": status,
      ]
    }
    return [
      "schemaVersion": Self.schemaVersion,
      "status": status,
      "rangeStartUtc": Self.timestamp(from: rangeStart),
      "rangeEndUtc": Self.timestamp(from: rangeEnd),
      "busyBlocks": busyIntervals.map { interval in
        [
          "startsAtUtc": Self.timestamp(from: interval.startsAt),
          "endsAtUtc": Self.timestamp(from: interval.endsAt),
        ]
      },
    ]
  }

  private static func timestamp(from date: Date) -> String {
    ISO8601DateFormatter.focusHavenUtc.string(from: date)
  }
}

private extension ISO8601DateFormatter {
  static let focusHavenUtc: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()
}
