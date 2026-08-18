import EventKit
import Foundation

enum HavenWindowCalendarAuthorization {
  case unsupported
  case disconnected
  case denied
  case ready
}

@MainActor
protocol HavenWindowCalendarReading: AnyObject {
  var authorization: HavenWindowCalendarAuthorization { get }

  func requestAccess() async throws

  func busyIntervals(from rangeStart: Date, to rangeEnd: Date) throws
    -> [HavenWindowBusyInterval]
}

@MainActor
final class EventKitHavenWindowCalendarReader: HavenWindowCalendarReading {
  private let eventStore: EKEventStore

  init(eventStore: EKEventStore = EKEventStore()) {
    self.eventStore = eventStore
  }

  var authorization: HavenWindowCalendarAuthorization {
    // Raw values keep the legacy iOS 15 authorized state and the iOS 17
    // full-access state on the same read-capable path without availability
    // checks leaking into the privacy contract.
    switch EKEventStore.authorizationStatus(for: .event).rawValue {
    case 0:
      return .disconnected
    case 1, 2, 4:
      return .denied
    case 3:
      return .ready
    default:
      return .unsupported
    }
  }

  func requestAccess() async throws {
    if #available(iOS 17.0, *) {
      _ = try await eventStore.requestFullAccessToEvents()
    } else {
      _ = try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Bool, Error>) in
        eventStore.requestAccess(to: .event) { granted, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume(returning: granted)
          }
        }
      }
    }
  }

  func busyIntervals(from rangeStart: Date, to rangeEnd: Date) throws
    -> [HavenWindowBusyInterval]
  {
    let predicate = eventStore.predicateForEvents(
      withStart: rangeStart,
      end: rangeEnd,
      calendars: nil
    )
    return eventStore.events(matching: predicate).compactMap { event in
      guard event.status != .canceled, event.availability != .free else {
        return nil
      }
      // Deliberately read only temporal boundaries. Event title, calendar,
      // attendees, location, notes, URL, and identifier never enter a model.
      return HavenWindowBusyInterval(
        startsAt: event.startDate,
        endsAt: event.endDate
      )
    }
  }
}

/// Consent-first native calendar coordinator for Haven Window.
@MainActor
final class HavenWindowNativeController {
  private static let queryDuration: TimeInterval = 24 * 60 * 60

  private let reader: HavenWindowCalendarReading
  private let now: () -> Date

  init(
    reader: HavenWindowCalendarReading? = nil,
    now: @escaping () -> Date = Date.init
  ) {
    self.reader = reader ?? EventKitHavenWindowCalendarReader()
    self.now = now
  }

  /// Reads current authorization and availability without requesting access.
  func readAvailability() throws -> HavenWindowAvailabilityPayload {
    switch reader.authorization {
    case .unsupported:
      return .unavailable(status: "unsupported")
    case .disconnected:
      return .unavailable(status: "disconnected")
    case .denied:
      return .unavailable(status: "denied")
    case .ready:
      let rangeStart = now()
      let rangeEnd = rangeStart.addingTimeInterval(Self.queryDuration)
      return try .ready(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        busyIntervals: reader.busyIntervals(from: rangeStart, to: rangeEnd)
      )
    }
  }

  /// The only native path allowed to display the EventKit permission prompt.
  func requestReadOnlyAccess() async throws -> HavenWindowAvailabilityPayload {
    guard reader.authorization == .disconnected else {
      return try readAvailability()
    }
    try await reader.requestAccess()
    return try readAvailability()
  }
}
