# Offline soundscapes — implementation scope

Status: integrated source verification, Android debug compilation/resources/
native unit tests, and unsigned iOS debug compilation passed. The subsequent iPhone
development-signed profile preview was installed and manually tested. Scoped
user-reported Moto and iPhone playback/accessibility observations are recorded
below; production-release qualification remains open.

Latest source update: offline media branding passed source verification and
updated Android debug/iPhone development-profile builds and installations.
The user reported successful branding and playback-control checks on both phones.
Earlier broader manual-test records apply to the pre-branding artifacts; only
the focused branding/control checks were repeated on the updated previews.

Isolated base: a087fc71bd5d25957b0fa035421f6f1452c49644.
The user selected continued playback while the phone is locked or another app is foreground.

## First version

- One original or appropriately licensed bundled sound; no streaming or download catalogue.
- Silence at startup. Explicit play/pause and volume controls; no automatic restoration of playing state after process restart.
- Background playback and media controls affect sound only, never the timer or queue.
- Pause on calls/audio interruptions and disconnected headphones; no unexpected automatic restart.
- Coordinate with existing tap-to-talk so playback cannot compete with microphone use.
- Complete readable controls with screen-reader labels and narrow/large-text layout coverage.
- Keep new copy outside production-language approval claims until it satisfies the existing localization policy. Do not overwrite reviewed translations with machine-generated guesses.

Resolved dependencies: just_audio 0.10.6, audio_service 0.18.19 and audio_session
0.2.4. The user resolved these successfully in the isolated checkout. The 26
lockfile additions are audio packages and transitive dependencies; existing
locked package versions were not intentionally upgraded.

Background playback requires an Android media service and iOS audio background configuration. The existing custom Android activity and platform channels must remain intact; audio engine lifecycle integration needs specific regression coverage. Do not add timer controls to the media session or widen assistant execution authority.

## Current tooling blocker

The first `flutter pub get` from this isolated checkout exited 134 before package resolution. Dart reported `cpuinfo_macos.cc: 42: error: unreachable code`. A separate read-only host check returned `Operation not permitted` for `sysctl -n machdep.cpu.brand_string`; `dart --version` itself succeeded. This is consistent with restricted host CPU queries in the execution environment, not an application compilation failure.

Dependency resolution subsequently succeeded in the user's normal terminal.
Flutter execution from the restricted agent environment remains unverified;
use the single source-verification command below from the normal terminal.

The original FocusHaven checkout and Phase 217M signed candidate are not modified by this preparation. No commit or push has been performed.

Maintainer references inspected during preparation:

- https://pub.dev/packages/just_audio
- https://pub.dev/packages/audio_service
- https://pub.dev/packages/audio_session
- https://pub.dev/packages/just_audio_background

## Implemented source

- A 30-second original filtered-noise PCM loop, reproducible using
  `tool/generate_soft_noise.py`. No third-party recording is used. Audition is
  pending; no claim of pleasantness, inaudible seams or therapeutic benefit.
- A sound-only controller with explicit play/pause/stop, bounded volume,
  cancellation during loading, error containment, and a microphone interlock.
- One Android/iOS audio handler, one asset player, sound-only media controls,
  explicit audio-focus handling, and no resume after interruptions. Playback
  errors require reopening the app; a failed subsystem does not stop the timer.
- An inline dashboard card below the main timer controls and before statistics.
  It is an **English development preview**, not approved localized production
  copy. It remains reachable if the app's language is changed during playback.
- Android background media service/receiver and iOS background audio declaration.
  The custom Android activity now subclasses AudioServiceActivity; its existing
  platform-channel methods and assistant capture-before-super order are retained.
  This changes engine lifecycle integration and requires native/lifecycle tests;
  Phase 217M acceptance cannot be transferred to this new source automatically.
- Audio-only exception in the Android ongoing-notification contract test:
  foreground service permissions are now constrained to base/mediaPlayback and
  the single declared audio service. Timer publisher no-service/no-private-data
  assertions remain intact.

The opt-in compile-time flag is `ENABLE_SOUNDSCAPES_PREVIEW=true`. It defaults
to false. Only Android/iOS playback is offered in this first preview; other
platforms remain unavailable rather than claiming mobile-background behavior.
The native declarations/dependencies still exist in this development branch
even with the preview flag off; the flag does not make it release-qualified.

## Verification

Run from the isolated checkout:

```bash
command /bin/bash tool/verify_soundscapes.sh
```

This one command checks the asset/platform boundaries, resolves cached packages
offline, generates localizations, formats only selected changed files, runs
targeted sound/voice/notification tests, analyzes the app and runs the complete
Flutter suite. It retains logs in a new sibling directory and stops on failure.
It does not package, sign, install, use a device, commit or push.

Successful normal-terminal run: `../phase218-verification-qDSaqx/`.
Three Python asset/declaration/import-boundary checks, selected-file formatting,
31 focused sound/voice/notification tests, full application analysis (no issues),
the complete 1,310-test Flutter suite, and Git whitespace checks all passed.
The focused tests are also included in the full suite, not additional unique
coverage. This establishes source/test verification, not native playback.
Earlier failed runs remain preserved; the fixes were accessibility-test handle
cleanup and braces around the audio-focus check, with test assertions unchanged.

Native check (offline mode for cached dependencies):

```bash
command /bin/bash tool/verify_soundscapes.sh --android-only
```

This reuses resolved dependencies without repeating the Flutter suite. It
refuses a checkout containing signing properties, copies missing generated
Gradle launcher files from the installed Flutter SDK without overwriting existing
files, and checks the offline Gradle task plan before phone debug compilation,
resource processing and native unit tests. The preview Dart flag is enabled for
this compilation. SDK auto-download is disabled. No APK/AAB, signing, installation,
device access or Wear task is requested; class/resource library intermediates
are allowed. Logs use the same durable sibling-directory convention. Missing
cached dependencies stop the check rather than enabling network resolution.
Shell syntax and synthetic task-plan acceptance/rejection checks passed; this
does not establish a successful native build.

The first native attempt (`../phase218-verification-BdjXmm/`) stopped during
offline configuration of `audio_service`: Kotlin Gradle plugin and plugin API
2.2.10 were not cached. Application compilation and native tests did not run.
The user authorized online resolution of existing Android build dependencies.
Use the same script with `--android-online` for that attempt. It retains the
same task-plan guard, signing-properties refusal and disabled SDK auto-download;
it does not edit dependency versions or use `--refresh-dependencies`. Online
resolution is opt-in; `--android-only` remains offline.

The authorized online/native run passed: `../phase218-verification-83s7Q6/`.
The task-plan guard accepted 404 planned tasks. Android phone debug compilation,
manifest/resource processing and native unit tests completed successfully;
the 10 native XML reports contain 54 tests, zero failures, zero errors and zero
skips. No app APK/AAB packaging or signing task was requested. Gradle/plugin
deprecation warnings remain maintenance items, not a reason to upgrade the
toolchain during this feature check. This result does not establish playback,
background service behavior, real Android lifecycle behavior or iOS support.

## Android listening preview (installed; scoped manual observations recorded)

```bash
command /bin/bash tool/build_soundscape_preview.sh --build-debug-preview
```

One ARM64 debug APK with `ENABLE_SOUNDSCAPES_PREVIEW=true`, using the existing
standard Android debug identity, not the production key. Resolution stays offline;
missing packaging dependencies cause a stop. The script refuses release signing
properties and checks the reviewed app Gradle configuration. A dry-run task guard
permits only phone debug packaging/signing, not release, app bundle, Wear or
device tasks. It records all nonignored source-file hashes before and after the
build, verifies the APK signature against the local debug certificate, and checks
package/version/debuggable metadata. Cached generated build outputs are reused;
the APK and identity record are preserved in a new private sibling
`phase218-preview-*` directory. Existing preserved candidates are not outputs.

The app ID remains `com.focushaven.app`. The debug signature may prevent updating
the release-signed app currently on the Moto; installation may require removing
that app and its local data. No uninstall, installation, launch or device query is
part of this build script. Those require a separate decision. A successful debug
preview is not release-build or real-device acceptance.

Shell and embedded Python syntax, native-versus-preview task-guard separation,
prohibited-task checks and whitespace passed during preparation.

The first preview attempt (`../phase218-preview-aCA9NV/`) built and debug-signed
the APK, and both signature checks passed. It stopped before publishing the
preserved preview because its version name was `1.0`, not `1.0.0`. Direct Gradle
invocation read Flutter's fallback version: local.properties lacked the version
inputs normally written by the Flutter CLI. The local generated settings now
match pubspec (`1.0.0+1`); the script checks their agreement before building and
includes local.properties in its before/after hashes. The APK identity assertions
remain unchanged. The corrected preflight passed, but the rebuilt artifact and
its final identity verification were pending at that stop. No installation occurred.

The corrected build passed in `../phase218-preview-2F9e4D/`. The preserved file
is `FocusHaven-phase218-soundscapes-debug.apk`, version `1.0.0+1`, debug mode,
ARM64 Flutter target, with soundscapes enabled. APK SHA-256:
`edfadec26715297fa93c09a159ddc4b3e0be361068feef6464dd06ada86427e7`.
Size: 103,880,408 bytes. Signature checks (default and API 36) passed, and the
certificate matched the local debug identity. Source manifests before and after
the build are identical. The preserved APK hash was independently rechecked.
At build completion no installation, device playback test or release approval
had occurred. Subsequent installation and observations are recorded below.

## Moto manual observations — recorded September 18, 2026

The authorized wireless installation passed in
`../phase218-moto-install-txm6xi7k/`. The saved Moto hardware identity was checked;
the old FocusHaven app and local data were removed as authorized. The installed
preview hash and size matched the artifact above. Accessibility/display settings
were unchanged. The installer did not launch the app or validate behavior.
Its historical result JSON remains unchanged.

The user then performed the following guided manual checks and reported each
worked. These are user-reported observations on the Moto g (2025), Android 16,
using this debug preview, not instrumented measurements or release approval:

| Manual check | Reported outcome |
| --- | --- |
| Startup and explicit playback | Opened normally, initially silent; Play/Pause worked; timer unchanged. |
| Home and lock screen | Sound continued; media controls worked; returning card state and idle timer were correct. |
| Volume and loop audition | Slider worked; no noticeable seam or unpleasant sound reported in the requested approximately 70-second listen. |
| Voice-input interlock | Sound paused for listening, stayed paused after cancellation; timer unchanged. |
| Force-stop and reopen | Sound stopped; reopened app stayed silent; explicit Play/Pause still worked. |
| TalkBack with sound | Controls/slider understandable and usable; value/volume changed; pause label/focus behaved as requested; speech comfortably audible. |

The user subsequently obtained headphones and explicitly confirmed all three
requested checks: audio played through the headphones; disconnection paused
playback without switching to the phone speaker; reconnection remained silent
until explicit Play. This is a user-reported pass for the tested headphones;
wired versus Bluetooth was not specified, so both routes are not claimed tested.
The user also reported the competing-audio check worked and subsequently
identified it as YouTube in the Moto's web browser (browser not specified).
Starting that playback paused Soft noise; stopping it did not automatically
resume Soft noise; explicit Play was required and the timer remained unchanged.
This does not establish native YouTube app behavior, call-interruption behavior
or compatibility with every app/audio-focus configuration.

Call interruption, iPhone playback/VoiceOver, release-mode behavior, localization
and broader assistant lifecycle checks remain open. No audio/screen capture was
used to corroborate these manual observations. The repeated brief confirmations
do not establish device-fleet coverage or quantitative latency/audio quality.
Wireless debugging pairing cleanup has not yet been confirmed.

## Unsigned iOS device-target compilation — passed

Prepared command: `bash tool/verify_soundscapes.sh --ios-only`.
Xcode 26.6 is installed and the audio plugins have Swift Package manifests. The
script exports nonignored source bytes to a new `/private/tmp` directory to
avoid the prior File Provider metadata issue. Original source is not used as the
build directory. It resolves Dart packages offline with the lock enforced,
generates localization outputs in the copy, and runs Flutter's debug iOS device-target
build with `--no-codesign --no-pub` and the soundscapes flag enabled. Xcode may
fetch missing Swift dependencies. Source/lock postchecks report any generated
project migrations and refuse changed dependency locks. No simulator is launched,
no device is accessed, and no account sign-in, archive or upload is requested.
Temporary output is retained with its path in the durable verification logs.
The initial simulator attempt is preserved in
`../phase218-verification-w0AVPZ/`. Dart resolution and localization generation
passed; Flutter stopped before app compilation because a watch companion exists
and no simulator ID was supplied. The installed Flutter implementation confirms
that this requirement applies to the simulator path. The same verification mode
now builds with `flutter build ios --debug --no-codesign --no-pub` instead, keeping
the watch integration intact and requiring no connected phone or simulator.
Shell and embedded Python syntax checks passed. The corrected build then passed
in `../phase218-verification-BCfsys/`: Xcode completed in 274.3 seconds and produced
`build/ios/iphoneos/Runner.app` in the retained temporary copy at
`/private/tmp/focushaven-phase218-ios-942XIT`. The source postflight confirms the
original source and dependency locks were unchanged; the build-copy tracked-file
change report is empty (`[]`). Whitespace verification also passed.
This establishes unsigned debug compilation only, not iPhone installation,
playback, VoiceOver, signed release validation or distribution approval.

## Authorized iPhone preview — installed, playback pending

The user identified an iPhone 12 Pro Max running iOS 26.6.2, confirmed that no
existing FocusHaven data needs preserving, and authorized a development-signed
preview build and installation. Normal Terminal reported the exact phone paired
and available, plus a valid Apple Development identity. Local profile metadata
includes development profiles for the app and widget/watch targets referencing
that certificate and the configured team. Phone UDID coverage was subsequently
verified by the installation preflight; metadata inspection alone was not treated
as signing validation.

`tool/install_ios_soundscape_preview.py --build-and-install-authorized-iphone`
checks the exact phone, Developer Mode, existing development identity and local
profiles before exporting verified application source to a fresh temporary copy.
It builds in Flutter profile mode with soundscapes enabled and verifies embedded
profiles and signing certificates before installing. Profile mode provides the
standalone preview without requiring an attached Flutter debug session. There is
no uninstall, automatic app launch, distribution signing, provisioning-update
permission, device registration, account change, archive or upload command.
If required local provisioning is unavailable, it stops without changing it.

Thirteen synthetic phone/profile guard cases, source hash checks, Python syntax,
and whitespace checks passed during preparation. No signed iPhone artifact or
installation result had been established at that point. Installation success does not by
itself qualify playback, VoiceOver or release readiness.

The first authorized run stopped in `../phase218-iphone-preview-54r0ujhg/`.
Phone identity, Developer Mode, certificate and local profile coverage passed,
but Xcode rejected a manual certificate SHA override combined with automatic
signing. All 100 recorded Xcode errors reported that conflict. Installation was
not attempted and original application source remained unchanged.
The existing script now uses `CODE_SIGN_IDENTITY=Apple Development`, requires
exactly one available Apple Development identity matching the authorized SHA,
and retains exact certificate checks on every signed app/extension before
installation. No provisioning-update permission or application edit was added.
At that stop, the corrected signed build and installation remained pending.

The retry in `../phase218-iphone-preview-896hwoj9/` completed the development-signed
profile build and deep/strict signature verification. It stopped before installation
because the certificate extraction command treated its space-separated output
prefix as an input path. The command now supplies `--extract-certificates=PREFIX`.
Original application source and the build-copy source are unchanged.

The same script's `--resume-built-preview` mode verifies and installs only that
preserved build, without dependency resolution, compilation or signing. It checks
the exact prior safe stop, source manifest and a pinned SHA-256 manifest of all
414 signed-app files, then repeats certificate/profile and exact-phone checks.
The prior evidence is not overwritten. Local source/artifact checks, drift refusal
checks and build-step exclusion checks passed; public-certificate verification
and installation in the user's normal Terminal were still pending. Certificate
extraction is not established by the restricted agent session.

The first resume in `../phase218-iphone-preview-usddddp3/` passed all four
certificate/profile checks but installation failed with a CoreDevice connection
reset. The user subsequently verified a connected device tunnel. A second resume
in `../phase218-iphone-preview-ikaawyxt/` repeated the identity, artifact, signature
and profile checks and successfully installed `com.focushaven.app` on the exact
authorized iPhone. The installer reports success, original application source
remains unchanged, and no rebuild, re-signing, uninstall or automatic launch was
performed during that resume. This is a development-signed profile-mode preview,
not distribution approval. iPhone playback and VoiceOver observations remain
pending at installation; the installation evidence does not infer behavioral validation.

### iPhone manual observations

After installation, the user reported all six guided basic checks worked on the
iPhone 12 Pro Max, iOS 26.6.2: normal manual startup, silence until explicit play,
Soft noise playback, audible volume-slider changes, pause stopping playback, and
sound controls leaving the stopped focus timer unchanged. These are user-reported
observations of the development-signed profile preview, not instrumented results
or production approval.

The user subsequently reported background playback through Home Screen and
phone locking, approximately 30 seconds of locked playback, lock-screen pause/
play, correct playback state on return and an unchanged stopped timer all worked.
Presentation exception: the iPhone media surface showed only "Soft noise", not
the FocusHaven name or logo. The user clarified that Android showed the name but
also lacked the logo. Media branding is not accepted as complete.

Source inspection confirms the media item supplies title "Soft noise" and album
"FocusHaven", but no artist or artwork URI. The installed iOS audio adapter maps
album, artist and artwork separately into Now Playing metadata. Missing explicit
artwork explains the absent provided brand artwork; album metadata alone did not
produce visible app branding in this reported iPhone layout. A possible scoped
follow-up is explicit creator/artist branding and existing local brand artwork,
without network fetching or playback/timer changes. No runtime correction has
been applied.

The user reported all three subsequent guided iPhone checks worked: audible
YouTube playback in Safari paused Soft noise and ending competing playback did
not automatically resume it; opening FocusHaven voice input paused sound and
cancelling without submitting a command did not automatically resume it; swiping
FocusHaven away stopped sound and reopening remained silent until explicit play.
The focus timer remained stopped throughout. These reports do not establish
telephone-call interruption behavior or other apps' audio-focus behavior.
The user subsequently reported all six guided VoiceOver checks worked: clear
sound heading/status, Play sound/Pause sound labels tracking playback, understandable
speech during playback, adjustable volume with announced and audible changes,
successful pause with the label returning to Play sound, and navigation out of
the sound section without trapping focus or starting the timer. These are manual
user observations, not an automated accessibility audit.

The user reported all five headphone checks worked using Bluetooth headphones:
sound played through the headphones, disconnecting paused it without continuing
through the phone speaker, reconnecting did not automatically resume playback,
explicit Play sound restored headphone playback, and the focus timer remained
stopped. This establishes user-reported Bluetooth coverage only; wired headphones
have not been tested on this iPhone.

The user reported the guided incoming regular-phone-call check worked and then
explicitly confirmed Bluetooth headphones remained connected. Per that report,
sound paused for the call, did not compete with the conversation, stayed paused
after the call ended, resumed only with explicit Play sound, and left the focus
timer stopped. The user subsequently repeated the call check without headphones
and reported everything worked as well, establishing a separate user-reported
pass for the same interruption/no-auto-resume/timer checks without headphones.
The speaker-versus-earpiece route was not specified; separate coverage for both
is not inferred. Calls through FaceTime/other calling apps are not established.

The planned iPhone manual functional round is complete on this preview with the
media-branding presentation issue still open. Media branding correction and
production acceptance remain pending. Wired-headphone coverage is not inferred
from the Bluetooth result, and these observations are not distribution approval.

### Offline media-branding correction — implemented, verification pending

The next isolated source update supplies artist/creator "FocusHaven" while
retaining title "Soft noise", album "FocusHaven" and the same media identity.
It bundles the existing square `assets/focushaven-lantern-icon.png` unchanged;
this icon is more legible at media-artwork sizes than the full wordmark. On sound
preparation, it copies the asset bytes to a fixed app-owned application-support
file and supplies its absolute file URI. The installed audio_service library
handles file artwork directly instead of using its remote cache loader.
Artwork load/write failure falls back to text metadata without disabling sound.
Remote or nonabsolute artwork URIs are refused by the metadata helper.

The already-locked path_provider 2.1.6 is now a direct dependency; no locked
package version or package hash changed. Controller/voice-interlock logic,
timer screen, sound controls, audio bytes and original lantern bytes are unchanged.
Nine new Flutter tests cover metadata, local bytes, ByteData offsets, generated
file refresh, remote URI rejection and asset/storage failures. They are included
in the existing source-verification command, not a separate continuation script.
Four Python asset/platform/source checks plus shell syntax and whitespace checks
passed locally. Flutter tests, formatter and analysis must still run in normal
Terminal. No new APK/iOS build, signing, installation, commit or push has occurred.
The existing signed-artifact/source checks intentionally do not accept changed
application source as the previously verified preview.

The first branding verification is preserved in `../phase218-verification-rrSunF/`.
Four asset/platform checks, offline dependency resolution, localization generation
and formatting checks passed. The focused Flutter run finished with 39 passes and
one failing URI rejection fixture; analysis and the full suite were not reached.
That fixture incorrectly expected `Uri.parse('file:brand.png')` to remain relative,
but Dart canonicalizes it to `file:///brand.png` before the helper receives it.
The test now rejects the actually relative `brand.png` instead, and a separate
normalization test documents the valid absolute-file result. This brings the new
metadata tests to ten. Runtime metadata validation and playback code are unchanged
by this correction. Four Python checks, shell syntax and whitespace checks passed
again; corrected Flutter verification was still pending at that stop.

The corrected verification passed in `../phase218-verification-l7hRpW/`:
four asset/platform checks, formatting, 41 focused Flutter tests, application
analysis with no issues, the complete 1,320-test Flutter suite, and whitespace.
The focused tests are a subset of the full suite, not an additional 41 unique
tests. This establishes source verification for the branding update, not updated
Android/iOS artifacts or device presentation. Prior installed previews and manual
observations remain intact; updated preview builds and a short media-branding/
playback-controls recheck on each phone remain pending.

The user authorized updated previews on the same iPhone and Moto using existing
development/debug identities and in-place updates, with no uninstall or data
clearing. The existing builders/installers now have explicit branding-update
modes. They share a read-only checkpoint of the five changed/new application
files relative to the earlier source plus the exact passing l7hRpW logs; all
other application source remains pinned. Both check that the packaged lantern
matches the existing local asset. The Android update mode verifies the currently
installed earlier preview and uses `adb install -r --no-streaming`; it cannot
execute the legacy replacement mode's uninstall branch. The iPhone retains
automatic development signing, exact certificate/profile verification and no
provisioning-update permission. Both preserve earlier artifacts/evidence and
leave the new app unopened.

Preparation checks passed: exact source/evidence checkpoint, changed-source
refusal, simulated in-place Moto update and wrong-model refusal, no uninstall/
clear on those update paths, Python/shell syntax, whitespace and four asset/
platform checks. These were local checks with mocked device commands, not builds
or installations. New Android/iOS branding artifacts and device results are
still pending execution in the user's normal Terminal at that checkpoint.

### Branding device follow-up

Android branding APK `../phase218-preview-AcDDPp/` was built and verified.
The first installation stopped before installation because ADB had no connected
device. Installation-only retry `../phase218-moto-install-5z95fd3l/` then passed:
the exact APK was updated in place, with no uninstall/data clearing or settings
change. The user reported that the Moto notification/lock-screen name, lantern
artwork and play/pause checks all worked. This is manual user-reported coverage,
not an automated accessibility or production-release qualification.

iPhone branding build `../phase218-iphone-preview-7fsbcd8k/` completed, including
app signature, four certificate/profile checks and packaged artwork verification.
Installation stopped with CoreDevice connection failure / `Connection reset by
peer`; installation success was not established at that stop. The signed app and source are
preserved. `install_ios_soundscape_preview.py --resume-branding-preview` verifies
that exact saved source and pinned app manifest, reruns the existing signature,
profile and phone checks, and retries installation without building or signing.
Local read-only checks confirmed the preserved app/source and rejection of
altered source/manifest identities. No retry was performed by the agent.
The user's installation-only retry `../phase218-iphone-preview-0l8nln9j/`
then reported success, with the original application source unchanged and no
rebuild or re-signing. After the focused manual checklist, the user reported
"everything worked": Soft noise title, FocusHaven name and lantern artwork in
Control Center and lock-screen media controls, working pause/resume and matching
in-app playback state. Both phones' preview branding checks are now complete
as user-reported observations. The installer result remains unchanged: it did
not launch or behaviorally validate the app, and no release approval is inferred.

External Google Assistant/Gemini invocation was explicitly deferred from first
release on September 18, 2026; see
[the scope decision](ANDROID_EXTERNAL_ASSISTANT_RELEASE_SCOPE.md). This does not
remove in-app voice/confirmation or waive soundscapes safety and release checks.

## Closeout review — September 18, 2026

Disposition: suitable for a default-off development-preview checkpoint, not
production enablement or a claim that all Phase 218 release gates are complete.
No staging, commit, push, phone action or rebuild was performed by this review.
The original main checkout remains clean; all feature changes are isolated.

The read-only branding checkpoint still matches the verified application source
and preserved 41-focused/1,320-total-test and analysis logs. Four lightweight
asset/platform checks and Git whitespace checks passed again during closeout;
the Flutter suite was not rerun. No new application-source changes were made.

Completed coverage includes bundled sound, explicit controls, silent restart,
background/media playback, voice-input coordination, headphone interruption,
and scoped TalkBack/VoiceOver observations. The iPhone also has user-reported
call-interruption checks with Bluetooth headphones and without headphones.
These observations and earlier native unit tests retain their original artifact
scope; no full-suite or native lifecycle pass is inferred for a different build.

Remaining before production enablement:

- Move English-only soundscape text/media labels into the approved localization
  workflow; retain the default-off preview flag until release acceptance.
- Verify a regular incoming-call interruption on Android. The recorded Moto
  competing-audio test used browser YouTube, not a phone call.
- Exercise retained in-app voice/platform-channel behavior across Android
  activity recreation/cold and warm startup with the new AudioServiceActivity
  base class. Earlier Phase 217M lifecycle evidence is not a substitute. This is
  local lifecycle coverage, not a restart of external App Actions qualification.
- Validate the intended signed release artifacts with a focused playback,
  interruption and accessibility pass; current Android debug and iOS profile
  previews are not release artifacts. Review release disclosures/claims.

Separately, the already-approved first-release assistant scope decision requires
a bounded legacy registration/claims cleanup before release. Do not start an
AppFunctions migration or re-open the deferred provider pipeline for this phase.

Proposed commit scope: product source/configuration, bundled asset, regression
tests, reusable verification/generator tools, and the scope/implementation docs.
Keep the four machine-bound preview helpers local: build_soundscape_preview.sh,
install_soundscape_preview.py, install_ios_soundscape_preview.py and
soundscape_branding_checkpoint.py. They pin personal device identities, local
artifact/evidence directories or depend on those pins; they are not reusable
product code. Preserve them and all evidence without staging them indiscriminately.
Use explicit paths when staging; do not use a blanket add. No commit is authorized
by this review. Timer/queue behavior and Phase 217M artifacts remain separate.
