# Delete Your FocusHaven Account

FocusHaven is created by Tyree Jones. This page provides an account-deletion
path for people who still have the app and for people who have uninstalled it
or can no longer open it.

## Delete your account in the app

If you can open FocusHaven:

1. Open the account sheet from the person icon on the timer screen.
2. Choose **Delete account**.
3. Review the permanent-deletion explanation and confirm **Delete account**.
4. Complete the Google or Apple sign-in prompt so FocusHaven can verify that
   the request belongs to you.

After the service confirms completion, FocusHaven deletes:

- your Firebase Authentication account;
- the complete `users/{uid}` cloud document, including any FocusHaven backup;
  and
- account-specific enhanced-coaching quota records derived from your Firebase
  user ID.

FocusHaven then returns the app to a new anonymous guest session. Local focus
data remains on that device unless you separately choose **Delete local data**.
Aggregate monthly service-limit records do not identify an account and are not
removed as part of an individual request.

For an Apple account, FocusHaven also attempts to revoke the Sign in with Apple
authorization. If Apple does not provide a revocable code or automatic
revocation fails, that condition does not block the verified account and cloud
data deletion. FocusHaven confirms the deletion and asks you to finish the
provider cleanup manually: on iPhone or iPad, open **Settings**, tap your name,
tap **Sign in with Apple**, choose FocusHaven, then choose **Delete** and
**Stop Using**. Apple documents the same control in
[Manage your apps with Sign in with Apple](https://support.apple.com/102571).

## Request deletion without the app

If you uninstalled FocusHaven or cannot access the in-app control, email
[90zbaby23@gmail.com](mailto:90zbaby23@gmail.com?subject=FocusHaven%20account%20deletion%20request)
with the subject **FocusHaven account deletion request**. Send the request from
the Google or Apple relay email address used for your FocusHaven account when
possible. Include only the email address needed to locate and verify the
account. Never send a password, authentication code, access token, journal
entry, coaching conversation, or focus history.

We may ask for a bounded verification step before deleting an account so one
person cannot delete another person's data. Once verified, the request covers
the Firebase Authentication identity, FocusHaven cloud document, and
account-specific enhanced-coaching quota records described above.

## Data controlled by other providers

Deleting a FocusHaven account does not delete:

- local data on a device that still has FocusHaven installed;
- Apple App Store or Google Play purchase and transaction records;
- data retained independently by Google, Apple, Firebase, OpenAI, or another
  provider under its own legal and security obligations; or
- content-free aggregate service limits that cannot be linked back to the
  deleted account.

Use the relevant device, store, or provider controls for data those providers
hold independently. See the [FocusHaven Privacy Policy](PRIVACY_POLICY.md) for
the complete data-handling explanation.

**Last updated:** August 24, 2026
