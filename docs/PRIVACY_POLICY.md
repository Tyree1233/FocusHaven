# FocusHaven Privacy Policy

**Effective date: August 24, 2026**

FocusHaven is a focus timer and wellbeing companion created by Tyree Jones. This policy explains what information FocusHaven uses and why.

## Information stored on your device

FocusHaven stores the following information locally on your device so its features work:

- timer settings, session history, daily goals, intentions, and parked thoughts;
- focus queue items, journal reflections, and mood selections;
- appearance and onboarding preferences;
- your Focus Coach conversation and whether you enabled enhanced AI coaching; and
- whether a FocusHaven Pro purchase has been recognized on the device.

Unless a section below says otherwise, this information remains on your device. Optional cloud backup sends only the supported focus data described in that section.

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

You may use FocusHaven as a guest. If you choose **Sign in with Google**, Google provides account information such as your name, email address, and a unique account identifier to authenticate you.

If you choose to back up or restore your data while signed in, FocusHaven stores your focus data in Google Firebase Cloud Firestore under your account. This can include the local information listed above, such as session history, goals, focus task, and related app preferences. Cloud backup is optional.

## Notifications

FocusHaven asks for notification permission only to send device-local reminders and session-completion messages. Notifications are generated on your device and are not used for advertising.

## Operational diagnostics

The released FocusHaven client does not include a third-party crash-reporting SDK and does not upload app-owned crash reports. Developer builds may print a stable technical event code and a coarse error category for local debugging. FocusHaven’s diagnostic boundary excludes exception messages, stack traces, user content, account or device identifiers, tokens, timestamps, URLs, request IDs, and arbitrary metadata, and the app does not retain or transmit that debug output.

The private enhanced-coaching function uses limited structured operational logs. FocusHaven’s application-defined log fields may contain an allowlisted event code, a coarse error category, an HTTP failure status, or a UTC quota month. Those fields do not deliberately include coaching prompts or replies, account identifiers, authentication state, provider request IDs, exception messages, or stack traces. The platform provider may separately create service, system-crash, or diagnostic records according to its infrastructure and your device or platform settings.

The detailed engineering boundary is documented in the [FocusHaven Privacy-Safe Diagnostics Policy](https://tyree1233.github.io/FocusHaven/DIAGNOSTICS_POLICY.html).

## Purchases

FocusHaven may offer optional in-app purchases. Purchases are processed by Google Play or Apple, as applicable. FocusHaven does not receive or store your payment-card number.

## How information is used

FocusHaven uses your information only to provide and improve the app’s features, including generating coaching responses you request, restoring backups you request, recognizing purchases, and sending the notifications you enable. FocusHaven does not sell personal information and does not use your coaching messages, journal entries, focus history, or parked thoughts for advertising.

## Service providers

FocusHaven uses Google Firebase for authentication, optional cloud backup, and the authenticated enhanced-coaching function. Google’s handling of information is described in the [Google Privacy Policy](https://policies.google.com/privacy). Enhanced AI coaching uses the OpenAI API; OpenAI describes its practices in its [Privacy Policy](https://openai.com/policies/privacy-policy/) and [API data controls](https://developers.openai.com/api/docs/guides/your-data).

## Data retention and deletion

You can delete your local coaching conversation from Focus Coach. Clearing all local app data or uninstalling the app also removes the locally saved conversation and enhanced-coaching preference. Turning enhanced coaching off prevents future coaching requests from being sent to OpenAI but does not alter any provider abuse-monitoring logs that may already be subject to OpenAI’s retention period.

If you used cloud backup and want your cloud-backed FocusHaven data deleted, contact us at the email below from the account used to sign in. We may need to verify the request before deleting associated backup data.

## Children’s privacy

FocusHaven is not directed to children under 13, and we do not knowingly collect personal information from children under 13.

## Changes to this policy

We may update this policy as FocusHaven changes. The effective date above will be updated when material changes are made.

## Contact

For privacy questions or data-deletion requests, contact:

Tyree Jones  
90zbaby23@gmail.com
