import Foundation
import WatchConnectivity

protocol SystemFocusWatchPublishing: AnyObject {
  func publish(snapshot: [String: Any])
}

/// Keeps one latest, text-free snapshot available to the paired watch.
final class SystemFocusWatchConnectivityBridge: NSObject, SystemFocusWatchPublishing {
  private let session: WCSession?
  private var pendingSnapshot: [String: Any]?

  init(session: WCSession? = WCSession.isSupported() ? .default : nil) {
    self.session = session
    super.init()
    session?.delegate = self
    session?.activate()
  }

  func publish(snapshot: [String: Any]) {
    guard let snapshot = SystemFocusWatchSnapshot.fromApplicationSnapshot(snapshot) else {
      return
    }
    pendingSnapshot = snapshot.wireDictionary
    publishIfAvailable()
  }

  private func publishIfAvailable() {
    guard let session,
      session.activationState == .activated,
      session.isPaired,
      session.isWatchAppInstalled,
      let pendingSnapshot
    else {
      return
    }
    do {
      try session.updateApplicationContext(pendingSnapshot)
      self.pendingSnapshot = nil
    } catch {
      // The latest snapshot remains pending for a later activation opportunity.
    }
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

  func sessionDidBecomeInactive(_: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
