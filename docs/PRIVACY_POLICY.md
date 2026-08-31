# FocusHaven Privacy Policy

**Effective date: August 30, 2026**

FocusHaven is a focus timer and wellbeing companion created by Tyree Jones. This policy explains what information FocusHaven uses and why.

## Information stored on your device

FocusHaven stores the following information locally on your device so its features work:

- timer settings, session history, daily goals, intentions, and parked thoughts;
- focus queue items, journal reflections, and mood selections;
- appearance and onboarding preferences;
- your Focus Coach conversation and whether you enabled enhanced AI coaching; and
- whether a FocusHaven Pro purchase has been recognized on the device.

Unless a section below says otherwise, this information remains on your device. Optional cloud backup sends only the supported focus data described in that section.

## Optional device permissions and private system surfaces

FocusHaven can optionally use calendar access for Haven Window suggestions. It reads only busy event start and end times to find a possible opening. Calendar names, event titles, notes, attendees, locations, URLs, and identifiers do not enter FocusHaven's model, and FocusHaven does not create, change, or delete calendar events. Calendar-derived time boundaries remain on your device.

On supported Apple devices, Focus Shield uses Apple's Family Controls and Managed Settings frameworks. Your selected applications, categories, and web domains are represented by opaque system tokens that remain in Apple system storage and FocusHaven's private on-device storage. They are not sent to Flutter, Firebase, OpenAI, or an advertising service.

FocusHaven's widgets, Android ongoing timer notification, Live Activity, Apple Watch app, and Wear OS app receive only a bounded timer snapshot: session type and activity, remaining and total seconds, and timestamps needed to render the timer. Interactive Android Home Screen and Lock Screen notification controls, Apple Watch, and Wear OS surfaces also receive a rotating private command identity. The iPhone Lock Screen widget, Live Activity, and Dynamic Island are read-only and receive no command capability. None of these surfaces receive your task, journal, mood, queue, parked thoughts, coaching conversation, or focus history.

## Voice-to-Coach

Voice-to-Coach is an optional tap-to-talk input for an editable Focus Coach
message. FocusHaven asks for microphone and speech-recognition access only when
you deliberately start this feature. It has no wake word, always-listening
mode, or background capture. You can deny permission and continue typing.

While the visible listening control is active, your device or browser speech
service converts speech into text. Depending on your platform, language, and
settings, that processing may occur on-device or over a network. FocusHaven
does not retain raw audio, write it to app storage, include it in cloud backup,
or send it to Firebase, OpenAI, analytics, diagnostics, or a FocusHaven server.

The recognized transcript remains an editable, session-only coaching draft.
You can stop listening, change the text, or discard it. Nothing is sent to
Focus Coach until you tap Send. After you send it, the transcript follows the
same local coaching-history and optional enhanced-coaching rules as a message
you typed. Voice-to-Coach cannot control the timer, change the Focus Queue,
delete data, make a purchase, grant permissions, or modify an account.

## Focus Coach and optional enhanced AI coaching

Focus Coach uses a local coaching responder by default. Your coaching conversation is saved on your device and is not included in cloud backup.

Enhanced AI coaching is optional and remains off until you explicitly enable it. When you enable it and send a coaching request, FocusHaven sends the following information through an authenticated Google Firebase function to OpenAI to generate a response:

- your current coaching message;
- up to 12 recent messages from the same coaching conversation; and
- relevant FocusHaven context, which can include your current focus task, focus profile, focus minutes and daily goal, remaining queue count and next task, recent mood summary, parked-thought count, and whether the timer is running.

FocusHaven does not send full journal reflections or your full focus history with a coaching request. The OpenAI API key is stored only on the server and is never included in the app. The function does not deliberately log coaching-message text, and FocusHaven does not maintain a server-side copy of the coaching conversation. If the function, network, or AI provider is unavailable, FocusHaven falls back to its local coach.

Enhanced requests use the OpenAI Responses API with response storage disabled (`store: false`). OpenAI states that API data is not used to train or improve its models unless the API account owner explicitly opts in. OpenAI may retain prompts, responses, and related metadata in abuse-monitoring logs for up to 30 days by default, unless a longer period is required by law or needed to protect its services or others from harm.

Messages that FocusHaven recognizes as an immediate self-harm or suicide concern are handled by the local responder and are not sent to enhanced AI coaching. Focus Coach supports wellbeing and productivity, but it is not professional healthcare or crisis care. You can turn enhanced AI coaching off at any time.

## Optional sign-in and cloud backup

You may use FocusHaven as a guest without providing your name or email address. When Firebase is available, FocusHaven automatically creates or restores an anonymous Firebase Authentication identity so protected services can distinguish one app user from another. Firebase Authentication processes a unique user identifier, IP address, app and user-agent metadata, and security information for authentication and abuse prevention.

If you choose **Sign in with Google**, Google provides account information such as your name, email address, federated account identifier, and authentication tokens handled by the Google and Firebase SDKs. If you choose **Continue with Apple** on a supported Apple device, Apple provides a federated account identifier, authentication credentials, and, depending on your choice, your name and email address or private relay address. FocusHaven uses that information only to authenticate your FocusHaven account and make optional cloud backup available.

If you choose to back up or restore your data while signed in, FocusHaven stores only the supported focus backup in Google Firebase Cloud Firestore under your account. It can include focus, short-break, and long-break durations; completed-session count; current focus task; daily goal; completed-session timestamps, durations, and optional task; and focus-event start/end times, planned and focused durations, pause count, resume status, outcome, and optional session-fit rating. Cloud backup does not include journal reflections, mood labels, queue items, parked thoughts, your focus profile, appearance choices, reminder settings, Focus Shield selections, calendar boundaries, or your coaching conversation.

FocusHaven also uses Firebase App Check and platform integrity services to protect Firebase resources from unauthorized clients. Those services process app and SDK metadata and an integrity or attestation token. FocusHaven does not use those signals for advertising.

## Notifications

FocusHaven asks for notification permission only from its reminder flow. When you grant it, FocusHaven can send device-local reminders and session-completion messages and can show one optional ongoing Android timer notification with generic Lock Screen controls. That ongoing surface contains only the bounded timer snapshot described above, never requests permission by itself, and is removed when the session no longer needs it or notification access is unavailable. Notifications are generated on your device and are not used for advertising.

## Operational diagnostics

The released FocusHaven client does not include a third-party crash-reporting SDK and does not upload app-owned crash reports. Developer builds may print a stable technical event code and a coarse error category for local debugging. FocusHaven’s diagnostic boundary excludes exception messages, stack traces, user content, account or device identifiers, tokens, timestamps, URLs, request IDs, and arbitrary metadata, and the app does not retain or transmit that debug output.

The private enhanced-coaching function uses limited structured operational logs. FocusHaven’s application-defined log fields may contain an allowlisted event code, a coarse error category, an HTTP failure status, or a UTC quota month. Those fields do not deliberately include coaching prompts or replies, account identifiers, authentication state, provider request IDs, exception messages, or stack traces. The platform provider may separately create service, system-crash, or diagnostic records according to its infrastructure and your device or platform settings.

The detailed engineering boundary is documented in the [FocusHaven Privacy-Safe Diagnostics Policy](https://tyree1233.github.io/FocusHaven/DIAGNOSTICS_POLICY.html).

## Purchases

FocusHaven may offer optional in-app purchases. Purchases are processed by Google Play or Apple, as applicable. FocusHaven receives the product identifier, purchase or restore status, and transaction information needed to recognize the entitlement, and stores the recognized Pro state on your device. FocusHaven does not receive or store your payment-card number.

## How information is used

FocusHaven uses your information only to provide and improve the app’s features, including generating coaching responses you request, restoring backups you request, recognizing purchases, and sending the notifications you enable. FocusHaven does not sell personal information and does not use your coaching messages, journal entries, focus history, or parked thoughts for advertising.

## Service providers

FocusHaven uses Google Firebase for authentication, optional cloud backup, and the authenticated enhanced-coaching function. Google’s handling of information is described in the [Google Privacy Policy](https://policies.google.com/privacy). Enhanced AI coaching uses the OpenAI API; OpenAI describes its practices in its [Privacy Policy](https://openai.com/policies/privacy-policy/) and [API data controls](https://developers.openai.com/api/docs/guides/your-data).

## Data retention and deletion

You can delete your local coaching conversation from Focus Coach. Clearing all local app data or uninstalling the app also removes the locally saved conversation and enhanced-coaching preference. Turning enhanced coaching off prevents future coaching requests from being sent to OpenAI but does not alter any provider abuse-monitoring logs that may already be subject to OpenAI’s retention period.

You can choose **Delete cloud backup** in the signed-in account controls. That permanently removes the `focusBackup` value stored in your Firestore account document while leaving the data on your device in place. Deleting a cloud backup is not the same as deleting the Firebase Authentication account.

You can choose **Delete local data** to remove the local timer history, coaching conversation, journal entries, tasks, parked thoughts, goals, focus profile, and appearance choices covered by that control. Feature-specific system permissions, notification schedules, store purchase history, and data held under a provider's own retention rules may require their separate controls or operating-system settings. Uninstalling the app removes its app-private local storage.

You can choose **Delete account** in the signed-in account controls. After an explicit confirmation, FocusHaven asks you to reauthenticate with your Google or Apple provider. For Apple accounts, FocusHaven also requests revocation of the Apple authorization when the provider returns the required authorization code. If Apple does not provide a revocable code or automatic revocation fails, FocusHaven still fulfills the verified account-deletion request, confirms the account and cloud-data deletion, and directs you to stop using Sign in with Apple for FocusHaven in your Apple Account settings. The protected deletion service removes the Firebase Authentication account, the complete `users/{uid}` cloud document, and account-specific enhanced-coaching quota records. FocusHaven does not claim success unless the service confirms completion. It then starts a fresh anonymous guest session. Local focus data remains on that device unless you separately choose **Delete local data**.

If you have uninstalled FocusHaven or cannot use its in-app control, use the public [FocusHaven account-deletion page](https://tyree1233.github.io/FocusHaven/ACCOUNT_DELETION.html) to initiate a verified deletion request without reinstalling the app. Store purchase records, provider security or legal-retention records, and content-free aggregate service limits are controlled separately as described on that page.

## Children’s privacy

FocusHaven is not directed to children under 13, and we do not knowingly collect personal information from children under 13.

## Changes to this policy

We may update this policy as FocusHaven changes. The effective date above will be updated when material changes are made.

## Contact

For privacy questions or data-deletion requests, contact:

Tyree Jones  
90zbaby23@gmail.com
