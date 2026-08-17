import Foundation
import WatchConnectivity

enum SystemFocusWatchCommandState: Equatable {
  case idle
  case sending
  case accepted
  case rejected
  case unavailable

  var message: String? {
    switch self {
    case .idle: return nil
    case .sending: return "Sending to iPhone…"
    case .accepted: return "Updated on iPhone"
    case .rejected: return "Timer changed. Sync again."
    case .unavailable: return "Open FocusHaven on your iPhone."
    }
  }
}

final class SystemFocusWatchModel: NSObject, ObservableObject {
  @Published private(set) var snapshot: SystemFocusWatchSnapshot?
  @Published private(set) var commandState = SystemFocusWatchCommandState.idle

  private let store: SystemFocusWatchSnapshotStore
  private let session: WCSession?
  private var pendingRequestId: String?
  private var handledSnapshotAtMilliseconds: Int?

  init(
    store: SystemFocusWatchSnapshotStore = SystemFocusWatchSnapshotStore(),
    session: WCSession? = WCSession.isSupported() ? .default : nil
  ) {
    self.store = store
    self.session = session
    snapshot = store.load()
    super.init()
    session?.delegate = self
    session?.activate()
  }

  func canSend(_ action: SystemFocusWatchAction) -> Bool {
    guard let snapshot,
      snapshot.availableActions.contains(action),
      commandState != .sending,
      handledSnapshotAtMilliseconds != snapshot.generatedAtMilliseconds
    else {
      return false
    }
    return true
  }

  func send(_ action: SystemFocusWatchAction, now: Date = Date()) {
    guard let snapshot, canSend(action),
      let command = SystemFocusWatchCommand.create(
        action: action,
        snapshot: snapshot,
        now: now
      )
    else {
      return
    }
    guard let session,
      session.activationState == .activated,
      session.isReachable
    else {
      commandState = .unavailable
      return
    }

    pendingRequestId = command.requestId
    commandState = .sending
    session.sendMessage(
      command.wireDictionary,
      replyHandler: { [weak self] value in
        DispatchQueue.main.async {
          self?.receiveCommandResult(value, for: command)
        }
      },
      errorHandler: { [weak self] _ in
        DispatchQueue.main.async {
          guard self?.pendingRequestId == command.requestId else { return }
          self?.pendingRequestId = nil
          self?.commandState = .unavailable
        }
      }
    )
  }

  private func receive(_ value: [String: Any]) {
    guard store.save(value), let snapshot = store.load() else { return }
    DispatchQueue.main.async { [weak self] in
      if self?.snapshot?.generatedAtMilliseconds != snapshot.generatedAtMilliseconds {
        self?.commandState = .idle
        self?.pendingRequestId = nil
        self?.handledSnapshotAtMilliseconds = nil
      }
      self?.snapshot = snapshot
    }
  }

  private func receiveCommandResult(
    _ value: [String: Any],
    for command: SystemFocusWatchCommand
  ) {
    guard pendingRequestId == command.requestId else { return }
    pendingRequestId = nil
    guard let result = SystemFocusWatchCommandResult.fromWireDictionary(value),
      result.requestId == command.requestId
    else {
      handledSnapshotAtMilliseconds = command.snapshotGeneratedAtMilliseconds
      commandState = .rejected
      return
    }
    handledSnapshotAtMilliseconds = command.snapshotGeneratedAtMilliseconds
    if result.accepted {
      commandState = .accepted
    } else {
      commandState = .rejected
    }
  }
}

extension SystemFocusWatchModel: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated, error == nil,
      !session.receivedApplicationContext.isEmpty
    else {
      return
    }
    receive(session.receivedApplicationContext)
  }

  func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receive(applicationContext)
  }
}
