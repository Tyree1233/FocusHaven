import Foundation
import XCTest

@testable import Runner

final class FocusShieldCapabilityPayloadTests: XCTestCase {
  func testDictionaryContainsOnlyTheVersionedTextFreeContract() {
    let payload = FocusShieldCapabilityPayload(
      isEnabled: true,
      nativeSupportAvailable: true,
      authorization: "approved",
      hasSelection: true,
      temporarilyPaused: false,
      nativeStatus: "protecting"
    )

    XCTAssertEqual(Set(payload.dictionary.keys), FocusShieldCapabilityPayload.keys)
    XCTAssertEqual(payload.dictionary["schemaVersion"] as? Int, 1)
    XCTAssertEqual(payload.dictionary["isEnabled"] as? Bool, true)
    XCTAssertEqual(payload.dictionary["authorization"] as? String, "approved")
    XCTAssertEqual(payload.dictionary["nativeStatus"] as? String, "protecting")
    XCTAssertNil(payload.dictionary["applicationTokens"])
    XCTAssertNil(payload.dictionary["webDomainTokens"])
    XCTAssertNil(payload.dictionary["focusTask"])
  }

  func testCapabilityVariationsNeverAddPrivateSelectionFields() {
    let payloads = [
      FocusShieldCapabilityPayload(
        isEnabled: false,
        nativeSupportAvailable: true,
        authorization: "notRequested",
        hasSelection: false,
        temporarilyPaused: false,
        nativeStatus: "inactive"
      ),
      FocusShieldCapabilityPayload(
        isEnabled: true,
        nativeSupportAvailable: true,
        authorization: "denied",
        hasSelection: false,
        temporarilyPaused: true,
        nativeStatus: "failed"
      ),
    ]

    for payload in payloads {
      XCTAssertEqual(Set(payload.dictionary.keys), FocusShieldCapabilityPayload.keys)
    }
  }
}
