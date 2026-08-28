# FocusHaven Account-Lifecycle Production Activation

This is the ordered production-activation runbook for Sign in with Apple,
Firebase App Check, and the protected `deleteFocusHavenAccount` callable. It is
an operator checklist, not an authorization to change production. Every write,
role grant, provider enablement, deployment, and destructive canary requires an
explicit approval at the gate where it appears.

No private key, App Check debug token, user identifier, authorization code,
access token, refresh token, password, credential JSON, or secret value belongs
in this file, a terminal transcript, a screenshot, Git, or CI output.

## Pinned production identity

| Boundary | Required value |
| --- | --- |
| Firebase / Google Cloud project | `focushaven-68c59` |
| Firebase project number | `791775983697` |
| Callable | `deleteFocusHavenAccount` |
| Callable region | `us-central1` |
| Apple team | `J3QFMX6H2P` |
| iPhone bundle ID | `com.focushaven.app` |
| iPhone widget bundle ID | `com.focushaven.app.widget` |
| Watch bundle ID | `com.focushaven.app.watchkitapp` |
| Firebase Apple return URL | `https://focushaven-68c59.firebaseapp.com/__/auth/handler` |

The repository pins the Firebase CLI default project alias to
`focushaven-68c59` through `.firebaserc`. Production commands in this runbook
still carry `--project focushaven-68c59` so their scope is explicit in operator
evidence. The committed alias is a guardrail, not a substitute for checking the
displayed project before any production write.

## Gate 0 — source and operator preflight (read only)

Required before opening any production console:

1. Start from a clean `main` branch synchronized with `origin/main`.
2. Record the commit SHA and the successful CI run IDs.
3. Confirm that `functions/index.js` still exports only the intended deletion
   callable under the exact name and region above.
4. Confirm the release client uses limited-use App Check tokens for deletion,
   initializes App Check after Firebase, and does not depend on the remote
   coaching feature flag.
5. Confirm the function enforces App Check, consumes limited-use tokens, and
   explicitly rejects `request.app.alreadyConsumed === true` before any data
   access or mutation.
6. Run the complete local verification and release builds.

Read-only Firebase identity checks, run from the repository root:

```sh
firebase login:list
firebase projects:list
firebase functions:list --project focushaven-68c59
```

Stop if the authenticated operator, project ID, existing function inventory,
repository SHA, or CI evidence is not exactly the expected value. These checks
do not authorize a deployment.

Evidence: timestamp, operator identity (without credentials), commit SHA,
clean status, Firebase project row, current function inventory, and CI URLs.

## Gate 1 — Apple capability and provider configuration

This gate requires an Apple Developer Program Account Holder or Admin. Apple
states that changing an App ID capability invalidates provisioning profiles
that contain that App ID, so they must be regenerated afterward.

After explicit approval:

1. In Certificates, Identifiers & Profiles, select the explicit App ID for
   `com.focushaven.app` and enable **Sign in with Apple**.
2. Preserve the existing application-group and Family Controls configuration;
   do not add Sign in with Apple to the widget or Watch target unless a later
   source change proves that target needs it.
3. Configure the required Services ID for the Firebase OAuth flow and register
   exactly the return URL pinned above.
4. Create or select the dedicated Sign in with Apple private key. Record only
   its key ID in the private credential inventory. Downloaded key material must
   go directly into approved secret storage and must never enter this repo.
5. If Firebase Authentication will send mail to Apple private-relay addresses,
   configure Apple's private email relay for the approved Firebase sender.
6. Regenerate affected development and distribution provisioning profiles,
   then refresh signing in Xcode.
7. In Firebase Console > Authentication > Sign-in method, enable Apple for
   project `focushaven-68c59` and enter the approved Services ID, Apple Team ID,
   private key, and key ID through the console's protected fields.

Stop if any displayed App ID, Team ID, Services ID association, return URL, or
Firebase project differs from the pinned values. Do not paste secrets into a
chat or terminal to troubleshoot.

Evidence: redacted screenshots of the enabled App ID capability and Firebase
provider state, profile regeneration timestamps, and a credential-inventory
reference that contains no secret value.

Rollback before release: disable the Firebase Apple provider, restore the last
approved profiles if required, and do not ship the Apple-enabled build. Never
delete or rotate a key as an improvised rollback; key changes require their own
approved credential procedure.

## Gate 2 — App Check registration and replay prerequisites

After explicit approval, in Firebase Console > App Check for project
`focushaven-68c59`:

1. Register the Android app for Play Integrity using the actual release-signing
   certificate configuration.
2. Register the Apple app for App Attest with DeviceCheck fallback. Confirm the
   Runner target declares
   `com.apple.developer.devicecheck.appattest-environment=production`; Firebase
   App Check does not accept App Attest tokens from the sandbox environment.
3. Register the web app with its production reCAPTCHA Enterprise site key.
   Supply that public site key to release web builds only through
   `FIREBASE_APP_CHECK_WEB_SITE_KEY`; do not commit it as a source default.
4. Register debug tokens only for named trusted development installations.
   Remove stale debug tokens and never use a debug provider in a release build.
5. Grant **Firebase App Check Token Verifier** to the second-generation
   function's default compute service account. Record the service-account email
   and role name, not any credential.
6. Leave product-wide enforcement changes separate from this callable rollout.
   First distribute attesting clients and monitor App Check metrics so valid
   production traffic is not unexpectedly rejected.

Stop if the app IDs, signing identities, provider type, service account, or
project do not match. A token-consumption deployment without the verifier role
is not production-ready.

Evidence: redacted App Check app registrations, verifier-role binding, debug
token inventory count, and a metrics baseline.

Rollback: disable callable traffic by rolling back the function revision or
remove the new client from release. Do not weaken source enforcement or switch
release builds to debug providers.

## Gate 3 — scoped deletion-function deployment

This is a production write and requires an explicit, separate approval after
Gates 0–2 pass. The only authorized first deployment command is:

```sh
firebase deploy \
  --only functions:deleteFocusHavenAccount \
  --project focushaven-68c59
```

Do not run an unscoped deploy, `--only functions`, or any command that includes
`focusCoach`. Record the pre-deployment function revision and configuration,
the exact source SHA, CLI version, operator, start/end times, command exit code,
and resulting revision. The function must remain in `us-central1` with App
Check enforcement, token consumption, bounded instances, and the recent-login
gate represented in source.

Rollback: route traffic back to the recorded prior healthy Cloud Run / Cloud
Functions revision using the Google Cloud console, or redeploy the last known
good tagged source with the same exact function/project scope. Do not delete
the callable while released clients depend on it.

### Recorded Gate 3 completion

Gate 3 deployment completed on August 28, 2026, under a separate explicit
authorization. The exact scoped command above ran from clean commit
`c70d264102396b9666f59b8db7459582964bc9dd` and created only
`deleteFocusHavenAccount` in project `focushaven-68c59`. Read-only before/after
inventory established that:

- `deleteFocusHavenAccount` is `ACTIVE` as a second-generation Node.js 22
  callable in `us-central1` under
  `791775983697-compute@developer.gserviceaccount.com`;
- its deployed limits remain 30 seconds, 256 MB, 1 CPU, 20 concurrency, and
  `maxInstances=10`;
- `focusCoach` remained byte-for-byte identical in the before/after Firebase
  inventory and `REMOTE_COACHING_ENABLED=false`;
- no third function was created; and
- no callable invocation, canary, Hosting deployment, IAM mutation, App Check
  product-enforcement change, provider or credential change, or remote-coaching
  change was performed.

This completion record proves the scoped deployment only. It does not authorize
or satisfy Gate 4, Gate 5, Gate 6, or any store release action.

## Gate 4 — non-destructive canary

Before deleting any test identity:

1. Install signed production-candidate builds on one supported Android device
   and one supported Apple device. Use a dedicated non-personal test account.
2. Verify Google and Apple authentication independently.
3. Confirm protected calls attach valid limited-use App Check tokens.
4. Confirm missing, invalid, and exactly replayed App Check tokens are rejected
   without deleting data.
5. Confirm an anonymous account and a stale provider session are rejected.
6. Confirm logs contain only the closed privacy-safe diagnostic fields.

Stop on any unexpected acceptance, project mismatch, personal account, private
log field, or unavailable rollback route.

Evidence: redacted request outcomes, function revision, platform/app versions,
App Check metrics, and content-free logs.

## Gate 5 — destructive test-account canary

This gate permanently deletes a dedicated test account and therefore requires
the test-account owner to approve the exact identity immediately beforehand.

For Google and Apple test accounts separately:

1. Create known test cloud data and record its expected bounded inventory.
2. Reauthenticate through the provider and confirm the destructive dialog.
3. Verify the callable deletes the Firebase Auth identity, the complete
   `users/{uid}` document, and the account-specific quota documents.
4. Verify the client returns to a new anonymous guest identity and does not
   delete local focus data.
5. For Apple, confirm automatic authorization revocation when a code is
   available. If not, verify deletion still succeeds and the app instructs the
   user to stop using Sign in with Apple manually.
6. Verify a second deletion attempt cannot claim another deletion.
7. Exercise the public account-deletion page and the bounded support workflow
   with another dedicated test identity before store submission.

Never perform this gate with the developer's personal Apple or Google account.

Evidence: pre/post inventory with account identifiers redacted, provider path,
callable revision, deletion response, Auth/Firestore absence, guest-session
state, Apple revocation outcome, and support-workflow completion time.

## Gate 6 — release decision and ongoing monitoring

Release only when every prior gate is signed off and the privacy policy, store
privacy disclosures, account-deletion URL, reviewer notes, and submitted build
all describe the same behavior.

For the initial rollout:

- monitor App Check accepted/rejected/replay metrics and callable errors;
- monitor deletion confirmations without logging account or content data;
- keep the prior function revision and store build available for rollback;
- investigate any increase in failed reauthentication or manual Apple
  revocation outcomes; and
- re-run this checklist whenever bundle IDs, signing certificates, Firebase
  apps, App Check providers, callable region, or deletion data scope changes.

## Official references

- [Apple: Enable app capabilities](https://developer.apple.com/help/account/identifiers/enable-app-capabilities)
- [Apple TN3194: Account deletion and token revocation](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
- [Apple Support: Manage apps with Sign in with Apple](https://support.apple.com/102571)
- [Firebase: Authenticate using Apple](https://firebase.google.com/docs/auth/ios/apple)
- [Firebase: App Check default providers for Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers)
- [Firebase: App Check for callable Cloud Functions](https://firebase.google.com/docs/app-check/cloud-functions)
- [Firebase: Deploy and manage specific functions](https://firebase.google.com/docs/functions/manage-functions)
- [Firebase CLI project selection](https://firebase.google.com/docs/cli)

## Activation status

As of August 28, 2026, operator-recorded console evidence establishes these
configuration checkpoints for the pinned production identities above:

- Sign in with Apple is configured for the FocusHaven iPhone App ID and the
  Firebase Authentication Apple provider is enabled. Its dedicated private-key
  material is held outside the repository; this document records no key value.
- Android App Check registration uses Play Integrity.
- Apple App Check registration uses App Attest with DeviceCheck fallback.
- The Runner App Attest entitlement is pinned to the production environment;
  watchOS and WidgetKit extension entitlements do not request App Attest.
- Web App Check registration uses reCAPTCHA Enterprise.
- The default second-generation Functions compute service account,
  `791775983697-compute@developer.gserviceaccount.com`, has the dedicated
  **Firebase App Check Token Verifier** role
  (`roles/firebaseappcheck.tokenVerifier`). The binding was independently
  verified in the project IAM principal and role views.
- `.firebaserc` pins the Firebase CLI alias to `focushaven-68c59`, while
  `firebase.json` defines the matching Hosting site, `build/web` public
  directory, and single-page application rewrite.
- Firebase Hosting remains undeployed.
- A read-only production function inventory recorded `focusCoach` as deployed
  and `ACTIVE` in `us-central1`, with `REMOTE_COACHING_ENABLED=false`. This
  account-lifecycle activation work did not deploy, enable, invoke, or modify
  that function.
- Gate 3 deployed only `deleteFocusHavenAccount` from clean commit
  `c70d264102396b9666f59b8db7459582964bc9dd`. It is `ACTIVE` as a
  second-generation Node.js 22 callable in `us-central1` under the verified
  compute service account. Before/after inventory confirmed that `focusCoach`
  remained byte-for-byte identical and that no other function was created.
- The controlled 1.0.0 (1) Apple archive passed App Store validation with
  non-blocking third-party framework symbol warnings.
- No App Store build was delivered, no TestFlight release was created, and
  nothing was submitted for review.

These checkpoints record completed configuration; they do not authorize or
claim the remaining activation gates. In particular:

- App Check enforcement remains disabled at the product level; the deployed
  callable retains its source-bound token enforcement and replay rejection;
- a new signed Apple production candidate must be archived and validated after
  the production App Attest entitlement correction before Gate 4 runs;
- remote coaching remains disabled; this activation runbook did not deploy,
  enable, invoke, or modify `focusCoach`;
- Gates 4 and 5 production canaries have not run;
- no callable invocation was performed; and
- no store release has occurred.

Any later console state can drift from this dated checkpoint. Re-run the
read-only identity checks and capture fresh redacted evidence before advancing
to Gate 4. No private key, site key, token, account identifier, or other secret
is stored in this status record.
