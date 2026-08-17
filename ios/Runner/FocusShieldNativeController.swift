import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI
import UIKit

/// Owns all opaque Family Controls tokens and Managed Settings mutations.
///
/// Flutter receives only [FocusShieldCapabilityPayload]. Application, category,
/// and web-domain tokens remain encoded in this app's private preferences.
@MainActor
final class FocusShieldNativeController {
  private enum Key {
    static let isEnabled = "focusShield.isEnabled"
    static let temporarilyPaused = "focusShield.temporarilyPaused"
    static let selection = "focusShield.selection"
    static let protectionActive = "focusShield.protectionActive"
  }

  private let defaults: UserDefaults
  private let authorizationCenter: AuthorizationCenter
  private let managedStore: ManagedSettingsStore
  private var protectionRequested = false
  private var operationFailed = false

  init(
    defaults: UserDefaults = .standard,
    authorizationCenter: AuthorizationCenter = .shared,
    managedStore: ManagedSettingsStore = ManagedSettingsStore()
  ) {
    self.defaults = defaults
    self.authorizationCenter = authorizationCenter
    self.managedStore = managedStore
  }

  var capability: FocusShieldCapabilityPayload {
    let enabled = defaults.bool(forKey: Key.isEnabled)
    let paused = enabled && defaults.bool(forKey: Key.temporarilyPaused)
    let selection = loadSelection()
    let hasSelection = Self.hasSelection(selection)
    let authorization = authorizationLabel
    let canProtect =
      enabled && authorization == "approved" && hasSelection && !paused
    let protecting =
      canProtect && defaults.bool(forKey: Key.protectionActive)
    let status = operationFailed
      ? "failed"
      : protecting
      ? "protecting"
      : "inactive"
    return FocusShieldCapabilityPayload(
      isEnabled: enabled,
      nativeSupportAvailable: true,
      authorization: authorization,
      hasSelection: hasSelection,
      temporarilyPaused: paused,
      nativeStatus: status
    )
  }

  func refreshAfterActivation() -> FocusShieldCapabilityPayload {
    if authorizationLabel != "approved" {
      clearProtection()
    } else if protectionRequested {
      applyProtectionIfPossible()
    }
    return capability
  }

  func setProtectionRequested(_ requested: Bool) -> FocusShieldCapabilityPayload {
    protectionRequested = requested
    operationFailed = false
    if requested {
      applyProtectionIfPossible()
    } else {
      clearProtection()
    }
    return capability
  }

  func perform(
    action: String,
    presentingViewController: UIViewController?
  ) async -> FocusShieldCapabilityPayload {
    operationFailed = false
    switch action {
    case "enable":
      guard !defaults.bool(forKey: Key.isEnabled) else { return capability }
      defaults.set(true, forKey: Key.isEnabled)
    case "disable":
      defaults.set(false, forKey: Key.isEnabled)
      defaults.set(false, forKey: Key.temporarilyPaused)
      clearProtection()
    case "requestAuthorization":
      guard defaults.bool(forKey: Key.isEnabled), authorizationLabel != "approved" else {
        return capability
      }
      do {
        try await requestAuthorization()
      } catch {
        operationFailed = true
      }
    case "chooseDistractions":
      guard
        defaults.bool(forKey: Key.isEnabled),
        authorizationLabel == "approved",
        let presentingViewController
      else {
        operationFailed = true
        return capability
      }
      if let selection = await presentPicker(from: presentingViewController) {
        saveSelection(selection)
        if protectionRequested {
          applyProtectionIfPossible()
        }
      }
    case "pauseProtection":
      guard defaults.bool(forKey: Key.isEnabled) else { return capability }
      defaults.set(true, forKey: Key.temporarilyPaused)
      clearProtection()
    case "resumeProtection":
      guard defaults.bool(forKey: Key.isEnabled) else { return capability }
      defaults.set(false, forKey: Key.temporarilyPaused)
      if protectionRequested {
        applyProtectionIfPossible()
      }
    case "retryProtection":
      guard defaults.bool(forKey: Key.isEnabled), protectionRequested else {
        return capability
      }
      applyProtectionIfPossible()
    default:
      operationFailed = true
    }
    return capability
  }

  private var authorizationLabel: String {
    let status = authorizationCenter.authorizationStatus
    if status == .approved { return "approved" }
    if #available(iOS 26.4, *), status == .approvedWithDataAccess {
      // FocusHaven deliberately uses only opaque tokens even when broader data
      // access happens to be available on the device.
      return "approved"
    }
    if status == .denied { return "denied" }
    return "notRequested"
  }

  private func applyProtectionIfPossible() {
    guard
      defaults.bool(forKey: Key.isEnabled),
      authorizationLabel == "approved",
      !defaults.bool(forKey: Key.temporarilyPaused),
      let selection = loadSelection(),
      Self.hasSelection(selection)
    else {
      clearProtection()
      return
    }

    let applications = selection.applicationTokens
    let categories = selection.categoryTokens
    let webDomains = selection.webDomainTokens
    managedStore.shield.applications = applications.isEmpty ? nil : applications
    managedStore.shield.webDomains = webDomains.isEmpty ? nil : webDomains
    managedStore.shield.applicationCategories = categories.isEmpty
      ? nil
      : .specific(categories)
    managedStore.shield.webDomainCategories = categories.isEmpty
      ? nil
      : .specific(categories)

    let accepted =
      managedStore.shield.applications == (applications.isEmpty ? nil : applications)
      && managedStore.shield.webDomains == (webDomains.isEmpty ? nil : webDomains)
      && (categories.isEmpty || managedStore.shield.applicationCategories != nil)
      && (categories.isEmpty || managedStore.shield.webDomainCategories != nil)
    defaults.set(accepted, forKey: Key.protectionActive)
    operationFailed = !accepted
  }

  private func clearProtection() {
    managedStore.shield.applications = nil
    managedStore.shield.applicationCategories = nil
    managedStore.shield.webDomains = nil
    managedStore.shield.webDomainCategories = nil
    defaults.set(false, forKey: Key.protectionActive)
  }

  private func requestAuthorization() async throws {
    if #available(iOS 16.0, *) {
      try await authorizationCenter.requestAuthorization(for: .individual)
      return
    }
    try await withCheckedThrowingContinuation { continuation in
      authorizationCenter.requestAuthorization { result in
        continuation.resume(with: result)
      }
    }
  }

  private func loadSelection() -> FamilyActivitySelection? {
    guard let data = defaults.data(forKey: Key.selection) else { return nil }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  private func saveSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else {
      operationFailed = true
      return
    }
    defaults.set(data, forKey: Key.selection)
  }

  private static func hasSelection(_ selection: FamilyActivitySelection?) -> Bool {
    guard let selection else { return false }
    return !selection.applicationTokens.isEmpty
      || !selection.categoryTokens.isEmpty
      || !selection.webDomainTokens.isEmpty
  }

  private func presentPicker(
    from presenter: UIViewController
  ) async -> FamilyActivitySelection? {
    await withCheckedContinuation { continuation in
      let view = FocusShieldPickerView(
        initialSelection: loadSelection() ?? FamilyActivitySelection(),
        onComplete: { selection in
          presenter.dismiss(animated: true) {
            continuation.resume(returning: selection)
          }
        }
      )
      let controller = UIHostingController(rootView: view)
      controller.modalPresentationStyle = .pageSheet
      controller.isModalInPresentation = true
      presenter.present(controller, animated: true)
    }
  }
}

private struct FocusShieldPickerView: View {
  @State private var selection: FamilyActivitySelection
  @State private var isCompleting = false
  let onComplete: (FamilyActivitySelection?) -> Void

  init(
    initialSelection: FamilyActivitySelection,
    onComplete: @escaping (FamilyActivitySelection?) -> Void
  ) {
    _selection = State(initialValue: initialSelection)
    self.onComplete = onComplete
  }

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle("Choose distractions")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { complete(nil) }
              .disabled(isCompleting)
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") { complete(selection) }
              .disabled(isCompleting)
          }
        }
    }
  }

  private func complete(_ value: FamilyActivitySelection?) {
    guard !isCompleting else { return }
    isCompleting = true
    onComplete(value)
  }
}
