import Foundation
import WatchConnectivity

protocol SystemFocusWatchPublishing: AnyObject {
  func publish(snapshot: [String: Any])
  func setCommandHandler(_ handler: SystemFocusWatchCommandHandler?)
}

typealias SystemFocusWatchCommandHandler = (
  _ command: [String: Any],
  _ completion: @escaping (Bool) -> Void
) -> Void

protocol SystemFocusWatchConnectivitySession: AnyObject {
  var delegate: WCSessionDelegate? { get set }
  var activationState: WCSessionActivationState { get }
  var isPaired: Bool { get }
  var isWatchAppInstalled: Bool { get }

  func activate()
  func updateApplicationContext(_ applicationContext: [String: Any]) throws
}

extension WCSession: SystemFocusWatchConnectivitySession {}

/// Keeps one latest, text-free snapshot available to the paired watch.
final class SystemFocusWatchConnectivityBridge: NSObject, SystemFocusWatchPublishing {
  private static let maximumRememberedRequestIds = 128

  private let session: SystemFocusWatchConnectivitySession?
  private let stateLock = NSLock()
  private var pendingSnapshot: [String: Any]?
  private var currentSnapshot: SystemFocusWatchSnapshot?
  private var commandHandler: SystemFocusWatchCommandHandler?
  private var consumedRequestIds: Set<String> = []
  private var requestOrder: [String] = []
  private var consumedSnapshotAtMilliseconds: Int?

  init(
    session: SystemFocusWatchConnectivitySession? = WCSession.isSupported()
      ? WCSession.default
      : nil
  ) {
    self.session = session
    super.init()
    session?.delegate = self
    session?.activate()
  }

  func publish(snapshot: [String: Any]) {
    guard let snapshot = SystemFocusWatchSnapshot.fromApplicationSnapshot(snapshot) else {
      return
    }
    stateLock.lock()
    currentSnapshot = snapshot
    pendingSnapshot = snapshot.wireDictionary
    stateLock.unlock()
    publishIfAvailable()
  }

  func setCommandHandler(_ handler: SystemFocusWatchCommandHandler?) {
    stateLock.lock()
    commandHandler = handler
    stateLock.unlock()
  }

  private func publishIfAvailable() {
    stateLock.lock()
    let snapshot = pendingSnapshot
    stateLock.unlock()
    guard let session,
      session.activationState == .activated,
      session.isPaired,
      session.isWatchAppInstalled,
      let snapshot
    else {
      return
    }
    do {
      try session.updateApplicationContext(snapshot)
      stateLock.lock()
      if Self.generatedAtMilliseconds(pendingSnapshot)
        == Self.generatedAtMilliseconds(snapshot)
      {
        pendingSnapshot = nil
      }
      stateLock.unlock()
    } catch {
      // The latest snapshot remains pending for a later activation opportunity.
    }
  }

  func receiveCommand(
    _ value: [String: Any],
    reply: @escaping ([String: Any]) -> Void,
    now: Date = Date()
  ) {
    guard let command = SystemFocusWatchCommand.fromWireDictionary(value) else {
      reply(
        SystemFocusWatchCommandResult(
          requestId: "invalid-request",
          accepted: false
        ).wireDictionary
      )
      return
    }

    stateLock.lock()
    guard let snapshot = currentSnapshot,
      let handler = commandHandler,
      command.isFresh(at: now),
      command.snapshotGeneratedAtMilliseconds == snapshot.generatedAtMilliseconds,
      snapshot.availableActions.contains(command.action),
      !consumedRequestIds.contains(command.requestId),
      consumedSnapshotAtMilliseconds != command.snapshotGeneratedAtMilliseconds
    else {
      stateLock.unlock()
      reply(
        SystemFocusWatchCommandResult(
          requestId: command.requestId,
          accepted: false
        ).wireDictionary
      )
      return
    }
    rememberLocked(command)
    stateLock.unlock()

    handler(command.applicationEnvelope) { accepted in
      reply(
        SystemFocusWatchCommandResult(
          requestId: command.requestId,
          accepted: accepted
        ).wireDictionary
      )
    }
  }

  private func rememberLocked(_ command: SystemFocusWatchCommand) {
    consumedRequestIds.insert(command.requestId)
    requestOrder.append(command.requestId)
    consumedSnapshotAtMilliseconds = command.snapshotGeneratedAtMilliseconds
    guard requestOrder.count > Self.maximumRememberedRequestIds else { return }
    consumedRequestIds.remove(requestOrder.removeFirst())
  }

  private static func generatedAtMilliseconds(_ value: [String: Any]?) -> Int? {
    guard let number = value?["generatedAtMilliseconds"] as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID(),
      !CFNumberIsFloatType(number)
    else {
      return nil
    }
    return number.intValue
  }
}

extension SystemFocusWatchConnectivityBridge: WCSessionDelegate {
  func session(
    _: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated, error == nil else { return }
    publishIfAvailable()
  }

  func sessionWatchStateDidChange(_: WCSession) {
    retryPendingSnapshotAfterWatchStateChange()
  }

  func retryPendingSnapshotAfterWatchStateChange() {
    publishIfAvailable()
  }

  func sessionDidBecomeInactive(_: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(
    _: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    receiveCommand(message, reply: replyHandler)
  }
}
