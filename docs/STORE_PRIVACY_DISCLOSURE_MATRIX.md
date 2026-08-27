# FocusHaven Store Privacy and Permission Disclosure Matrix

**Audit date: August 27, 2026**

This document is the source-backed working record for FocusHaven's Apple App
Store privacy answers, Google Play Data safety answers, permission explanations,
and review notes. It is not a substitute for the forms in App Store Connect or
Play Console. Those forms must be rechecked against the exact binaries and SDK
versions submitted to each store.

No store answer should claim that FocusHaven collects no data. Every app launch
creates or restores an anonymous Firebase Authentication identity, and the
Firebase SDKs process authentication and service metadata. Additional data is
sent only after a person chooses Google sign-in, cloud backup, or enhanced AI
coaching.

## Submission status

FocusHaven is **not yet ready for public store submission**. The following
items are release blockers rather than documentation suggestions:

1. **Apple login activation:** the source now offers Firebase's native Apple
   provider as an equivalent option on supported Apple devices and declares the
   Sign in with Apple capability. Before App Store submission, the developer
   must complete Apple Developer enrollment, enable and configure the provider
   in Firebase, regenerate distribution provisioning, and pass signed-device
   and end-to-end authentication tests.
2. **Account-deletion deployment:** the source now includes a confirmed in-app
   deletion flow, protected callable cleanup, and public external deletion
   resource. Before either store submission, the callable must be deployed and
   in-app Google/Apple deletion plus the external request process must pass
   production-project validation. The external URL must then be entered in
   Play Console. Follow the ordered, approval-gated
   [account-lifecycle production activation runbook](ACCOUNT_LIFECYCLE_PRODUCTION_ACTIVATION.md);
   its existence does not claim that any production step has run.
3. **Family Controls distribution approval:** shipping Focus Shield on Apple
   platforms requires the production Family Controls entitlement and any
   approval, provisioning, and review material Apple requires.
4. **Store administration:** the developer must finish the applicable account,
   agreements, tax/banking, trader-status, age-rating, privacy, Data safety,
   and app-content forms. Repository tests cannot complete or validate those
   external forms.

The narrower in-app **Delete cloud backup** action still removes only the
`focusBackup` field and leaves the account intact. The separate **Delete
account** action requires provider reauthentication and invokes the protected
`deleteFocusHavenAccount` callable. That callable atomically removes the
complete user document and every bounded account-specific quota record before
deleting the Firebase Authentication user. It preserves content-free aggregate
service limits. The app claims success only after the callable confirms it.

## Shipped permission and entitlement inventory

### Android phone app

| Permission or capability | Why it exists | Request or activation boundary | Data handling |
| --- | --- | --- | --- |
| `POST_NOTIFICATIONS` | Local reminders, timer-completion notices, and one optional text-free ongoing timer with Lock Screen controls | Requested only from a reminder flow; the ongoing surface never prompts by itself | Notification content, schedules, and bounded timer snapshot remain on device |
| `READ_CALENDAR` | Optional Haven Window suggestions | Requested only after the user chooses to review calendar access | Reads busy start/end boundaries only; titles, calendar names, notes, attendees, locations, URLs, and identifiers do not enter the model or leave the device |
| `RECEIVE_BOOT_COMPLETED` | Restore locally scheduled reminders and reconcile an already-authorized ongoing timer after reboot | No runtime prompt | Does not collect reboot history |
| `VIBRATE` and `WAKE_LOCK` | Local notification delivery | Indirect plugin permissions | No user data is collected for these capabilities |
| `INTERNET` and `ACCESS_NETWORK_STATE` | Firebase authentication, optional backup, enhanced coaching, Google sign-in, and purchases | Network access follows the feature boundaries below | All application network endpoints use encrypted transport; cleartext traffic is disabled |
| `BILLING` | Optional Google Play purchase and restore flow | Only after a purchase or restore action | Google Play processes payment details; FocusHaven receives product and transaction status, not payment-card numbers |
| Google/Firebase service permissions and signature-scoped receiver permission | Authentication, App Check, and integrated Google services | SDK-managed | Must be re-audited from the merged release manifest for every submission |

The Android source manifest does not request location, contacts, camera,
microphone, photos/media, SMS, call logs, accessibility service, VPN, or health
permissions. The merged release manifest is authoritative because dependencies
may add permissions.

### Apple phone, widget, and Watch app

| Permission or entitlement | Why it exists | Request or activation boundary | Data handling |
| --- | --- | --- | --- |
| Calendar event access | Optional Haven Window suggestions | Requested only after the user chooses to review calendar access | EventKit's full-event authorization API is required on modern iOS, but FocusHaven reads only busy start/end boundaries and never calls calendar write APIs |
| Notification authorization | Local reminders and timer-completion notices | Requested only from a reminder flow | Notifications are scheduled locally |
| `com.apple.developer.family-controls` | Optional Focus Shield | Authorization and selection are explicit user actions | Opaque application, category, and web-domain tokens stay in app-private storage and are never exposed to Flutter or sent off device |
| App group `group.com.focushaven.app` | Share the bounded timer snapshot and private command capability with the widget | Active only inside FocusHaven's signed containers | Shared state excludes tasks, history, journal text, moods, and coaching content |
| Watch connectivity | Send the bounded timer snapshot and replay-protected commands between the paired phone and Watch | Used only by the companion surfaces | Watch payloads exclude user-authored content and private selections |

The iOS app does not declare camera, microphone, contacts, photos, location,
HealthKit, or tracking usage descriptions. FocusHaven does not use the
Advertising Identifier or App Tracking Transparency framework.

## End-to-end data-flow inventory

| Flow | Data | Required or optional | Destination and retention | User control |
| --- | --- | --- | --- | --- |
| Local focus experience | Timer settings and state, session history, goals, focus task, queue items, parked thoughts, journal reflections and moods, focus profile, appearance/onboarding settings, coaching conversation, reminder settings, and recognized Pro state | Required for the feature that stores it | App-private device storage | Delete local data, feature-specific clear controls, OS app-data clearing, or uninstall |
| Calendar assistance | Busy event start/end boundaries and derived open windows | Optional | On-device only; not included in cloud backup or coaching | Deny/revoke calendar access or leave Haven Window off |
| Focus Shield | Opaque Family Controls selections and coarse authorization/protection state | Optional | Apple system stores and app-private device storage | Disable Focus Shield, change selection, or revoke authorization |
| System widgets, Android ongoing notification, and watches | Session type, activity, remaining/total seconds, generated/deadline timestamps, and rotating command capability | Optional surface | App group, app-private preferences, local notification, or paired-device transport | Remove the widget/companion app, revoke notification access, or reset/stop the timer |
| Anonymous authentication | Firebase Authentication user ID, IP address, Firebase/user-agent metadata, app identifier, and security metadata | Automatic when Firebase is available | Google Firebase Authentication according to the configured project and Firebase terms | Guests do not receive signed-in cloud-backup storage; signing into a provider replaces the guest session, and confirmed signed-in account deletion returns the app to a fresh guest identity |
| Google sign-in | Name, email address, Google/federated identifier, Firebase user ID, authentication tokens handled by the SDK, IP and service metadata | Optional | Google Sign-In and Firebase Authentication | Sign out; confirmed account deletion reauthenticates before removing the Firebase identity and associated FocusHaven cloud data |
| Apple sign-in | Apple/federated identifier, authentication credentials, and optional name, email, or private relay address | Optional on supported Apple devices after production activation | Apple and Firebase Authentication | Sign out; confirmed account deletion reauthenticates and attempts automatic Apple authorization revocation. Missing or failed revocation cannot block verified deletion; the app directs the user to stop using Sign in with Apple manually |
| Cloud backup | Focus duration settings; completed-session count; current focus task; daily goal; completed-session timestamps, durations, and optional task; focus-event start/end timestamps, planned/focused durations, pause count, resume flag, outcome, and optional session-fit rating | Optional and user initiated | `users/{uid}.focusBackup` in Cloud Firestore until deletion or replacement | Delete cloud backup in app; restore/replace backup; full account deletion must also remove associated data |
| Enhanced AI coaching | Current message; up to 12 recent coaching messages; optional current focus task, profile, next queue task, and recent mood; focus minutes, daily goal, queue and parked-thought counts, and timer-running state | Optional, off by default, request initiated | Firebase callable function and OpenAI Responses API; `store: false`; provider abuse-monitoring retention may still apply as described in the privacy policy | Keep enhanced coaching off, turn it off, or clear local coaching history |
| Enhanced-coaching quota | SHA-256 hash of Firebase UID as part of a monthly document ID; UTC month; used count; update time | Only for enhanced coaching | Private Firestore quota collection | Account-specific records are removed by confirmed account deletion; content-free global monthly limits remain |
| App Check | Firebase user agent and platform integrity/attestation token | Automatic for protected Firebase calls | Firebase App Check and the platform attestation provider | Required to protect the backend; no advertising use |
| Purchases | Product identifier, purchase status, transaction/purchase identifier and restore result supplied by Apple or Google | Optional | Store provider; recognized entitlement is stored locally | Store purchase controls and restore flow |
| Privacy-safe diagnostics | Closed technical event code and coarse error kind in debug builds; bounded function log fields for provider/quota failures | Operational | Client release logging is disabled; function logs follow the diagnostics policy | No user-content fields are accepted; platform diagnostic settings remain under OS/provider control |

FocusHaven has no advertising SDK, analytics SDK, third-party client crash
reporter, contact upload, location collection, photo/media upload, voice capture,
or sale of personal data.

## Archive-checked Apple App Privacy answers

The conservative answer to **Data Collection** is **Yes**. The following is the
working label for the exact Apple-validated `1.0.0 (1)` candidate at commit
`d37f57281159ff7e8b0d80e970d243fc2ae3c04d` (IPA SHA-256
`32d98bfe74fd1947c6b53a1b7d534fde3fe5ba0b7e090c5afd7866e0654600dd`).
The archive contains 39 third-party privacy manifests. Every manifest that
declares tracking sets its tracking value to false, every collected-data entry
sets its tracking value to false, and no tracking domain is declared.

The table combines FocusHaven's application flows with the collected-data
entries embedded in the exact archive. **App Functionality** is the primary
purpose. Where Google or Firebase's embedded manifest also declares
**Analytics**, that purpose must remain in the store answer even though
FocusHaven does not include Firebase Analytics or another developer analytics
SDK. Nothing is used for third-party advertising, developer
advertising/marketing, or tracking.

| Apple data type | Collected? | Linked to identity? | Why |
| --- | --- | --- | --- |
| Contact Info — Name | Optional | Yes | Google Sign-In / Firebase Authentication |
| Contact Info — Email Address | Optional | Yes | Google Sign-In / Firebase Authentication |
| Contact Info — Phone Number | SDK-declared | Yes | Google Sign-In's archive privacy manifest declares phone number for App Functionality; FocusHaven does not request a phone-number scope or expose a phone-number field |
| Location — Coarse Location | SDK-declared | Yes | Google Sign-In's archive privacy manifest declares coarse location for App Functionality; FocusHaven does not request device location permission |
| Identifiers — User ID | Yes | Yes | Anonymous or signed-in Firebase Authentication account; Google Sign-In; Firestore and function requests; App Functionality, with Google Sign-In also declaring Analytics |
| Identifiers — Device ID | SDK-declared | Yes | Google Sign-In and reCAPTCHA Enterprise archive privacy manifests; security, integrity, App Functionality, and the SDK-declared Analytics purpose |
| User Content — Other User Content | Optional | Yes when authenticated | Focus tasks and session content in cloud backup; messages and selected context in enhanced coaching |
| Usage Data — Product Interaction | Yes | Yes | Optional backed-up session activity plus reCAPTCHA Enterprise's App Functionality declaration |
| Usage Data — Other Usage Data | SDK-declared | Yes | Google Sign-In's archive privacy manifest declares other usage data for Analytics |
| Other Data | SDK-declared | Yes | Google Sign-In's archive privacy manifest declares other data types for App Functionality and Analytics |
| Purchases — Purchase History | Optional | Yes through store account | Product and transaction status used to recognize/restore Pro |
| Diagnostics — Crash Data | SDK-declared | Yes | reCAPTCHA Enterprise declares crash data for App Functionality; FocusHaven does not include Crashlytics or another app-owned client crash reporter |
| Diagnostics — Performance Data | SDK-declared | Yes | reCAPTCHA Enterprise declares performance data for App Functionality |
| Diagnostics — Other Diagnostic Data | SDK-declared | No | Firebase Authentication, Firestore, Firestore Internal, and Installations declare other diagnostic data for Analytics |

On-device calendar boundaries, Family Controls selections, journal entries,
queue items, parked thoughts, and local coaching messages are not collected for
the Apple label unless they enter an optional transmitted flow described above.
FocusHaven does not track users.

These answers must be re-audited if the submitted binary differs from the
fingerprint above. App Store Connect answers must cover every third-party
partner integrated into every platform for the app, not only the data fields
FocusHaven accesses directly.

## Preliminary Google Play Data safety answers

The conservative answer to **Does your app collect or share required user data
types?** is **Yes, data is collected**. A transfer to Google Firebase or OpenAI
may qualify for Google's service-provider exception from “sharing,” but the
data is still collected. Claim **not shared** only after confirming the
processor contracts, configuration, and Play definitions at submission time.

| Play data type | Collection | Required or optional | Purpose |
| --- | --- | --- | --- |
| Personal info — Name | Optional | Google sign-in only | Account management / app functionality |
| Personal info — Email address | Optional | Google sign-in only | Account management / app functionality |
| Personal info — User IDs | Required when Firebase is available | Anonymous UID is automatic; federated ID is optional | Authentication, security, backup, enhanced coaching |
| App activity — App interactions / Other actions | Optional | Cloud backup only | Restore focus session history, timer outcomes, and goal progress |
| Messages or Other user-generated content | Optional | Cloud backup and enhanced coaching | Back up a focus task; generate the requested coaching response |
| Device or other identifiers | Required for protected network features | SDK/App Check managed | Fraud prevention, security, and app functionality |
| Approximate location | Requires final provider mapping | Firebase Authentication and Functions collect IP addresses; declare this if IP-derived location is processed under the current Play definition | Security, fraud prevention, and app functionality |
| App info and performance — Diagnostics | Conservatively Yes | Firebase service metadata is automatic | Maintain service compatibility and security; no app-owned crash reporter |
| Financial info — Purchase history | Optional | Purchase/restore only | Recognize and restore Pro; no payment-card data |

Security answers supported by the current implementation:

- application endpoints use encryption in transit; Android cleartext traffic
  is disabled and Firebase documents HTTPS transport;
- cloud backup is optional and unavailable to anonymous guests;
- Firestore rules restrict `users/{uid}` to that non-anonymous owner and deny
  all other client paths;
- no data is sold or used for advertising; and
- the source includes both in-app deletion and the public external deletion
  resource, but the Play declaration remains blocked until the callable and
  external verification process pass production-project validation.

On-device-only data is outside Google Play's collection definition. Calendar
boundaries, Focus Shield selections, and text-free system-surface snapshots are
therefore permissions/capabilities to explain, not off-device collection.

## Store review notes to prepare

Review notes should make these boundaries easy to verify:

1. The core timer works without Google sign-in, calendar access, notification
   permission, Focus Shield, enhanced coaching, or a purchase.
2. Haven Window asks for calendar access only after a deliberate action and
   reads only time boundaries. It never creates, edits, or deletes events.
3. Focus Shield requires explicit Apple authorization and a separate opaque
   selection; denial leaves the timer fully usable.
4. Enhanced coaching is off by default, clearly identifies the Firebase/OpenAI
   transfer, and falls back to the local coach.
5. Cloud backup is separately user initiated and contains only the exact
   fields listed in this matrix.
6. Widget, Live Activity, Watch, and Wear OS payloads are text-free and
   replay-protected.
7. Subscription checkout is not active. Existing lifetime-owner restoration
   remains available under the repository's purchase-transition rules.
8. Provide App Review a fully functional guest path plus any account or
   entitlement instructions needed to exercise optional features.

## Official references used for this audit

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple — Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Apple — Handling account deletions and revoking Sign in with Apple tokens](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple App Store Connect — Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Google Play Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Firebase Android data-disclosure guidance](https://firebase.google.com/docs/android/play-data-disclosure)
- [Firebase Apple data-collection guidance](https://firebase.google.com/docs/ios/app-store-data-collection)
- [Firebase Flutter federated authentication](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Android notification runtime permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- [Android notification and Lock Screen visibility](https://developer.android.com/develop/ui/compose/notifications/create-notification)

This matrix must be reviewed whenever a permission, entitlement, SDK, backend
field, authentication provider, purchase path, diagnostic path, or remote data
flow changes.
