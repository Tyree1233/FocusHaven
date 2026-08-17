import Foundation
import WatchConnectivity

final class SystemFocusWatchModel: NSObject, ObservableObject {
  @Published private(set) var snapshot: SystemFocusWatchSnapshot?

  private let store: SystemFocusWatchSnapshotStore
  private let session: WCSession?

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

  private func receive(_ value: [String: Any]) {
    guard store.save(value), let snapshot = store.load() else { return }
    DispatchQueue.main.async { [weak self] in
      self?.snapshot = snapshot
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
