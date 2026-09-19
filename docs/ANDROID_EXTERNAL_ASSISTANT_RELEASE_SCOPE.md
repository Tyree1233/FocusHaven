# External Android assistant integration — first-release scope

Decision recorded September 18, 2026. The product owner explicitly approved
deferring external Google Assistant/Gemini invocation from FocusHaven's first
release, preserving reusable work, and continuing Phase 218 soundscapes.

## Provider evidence and interpretation

The user supplied a reply from Ben, App Actions Support, to the prior technical
inquiry. Support states that new/in-development App Actions integrations,
including OPEN_APP_FEATURE and custom intents, cannot currently be approved or
pushed to production because the pipelines are broken. Support no longer
recommends App Actions, reports the AppFunctions EAP is full, and supplies no
general-availability date. These statements are attributed to the supplied
support email, not independently retrieved mailbox contents or a public sunset
notice for every existing integration.

Official documentation checked September 18, 2026:

- [AppFunctions overview and FAQ](https://developer.android.com/ai/appfunctions):
  local implementation/testing is possible, but the API is experimental and
  end-to-end agent access is limited. EAP interest registration is not access.
- [Google's mobile Assistant transition announcement](https://blog.google/products-and-platforms/products/gemini/google-assistant-gemini-mobile/):
  context for the transition to Gemini, not proof of FocusHaven eligibility.
- [Google Home cloud-to-cloud](https://developers.home.google.com/cloud-to-cloud/get-started):
  connected smart-home device integration, not a suitable substitute for this
  focus-timer app's external mobile invocation path.

## Approved first-release decision

- External Google Assistant/Gemini invocation is deferred, not a first-release
  prerequisite or a promised supported feature.
- Stop speculative legacy App Actions diagnostics and production-approval work.
- Do not begin an AppFunctions migration or Google Home integration now. Revisit
  only with confirmed eligible end-to-end access and a bounded product proposal.
- Preserve in-app voice, review/confirmation, action validation, accessibility
  improvements and regression tests. None is removed or given new execution
  authority by this decision.
- Continue Phase 218 independently. Its passing Android checks do not waive its
  remaining iOS, release-mode, localization or other applicable acceptance work.

## Phase 217M and evidence disposition

External provider qualification is blocked and deferred from first-release scope.
Phase 217M is not represented as successfully completed, provider-approved or
release-qualified. Its original candidate-validation contract remains historical
and unchanged; unmet official-tool/locale/provider requirements are deferred,
not converted to passes. If this integration is resumed, re-evaluate its contract
against the then-supported provider path before relying on old evidence.

Internal safety/accessibility/state-preservation requirements still apply to
features retained in the release. Reuse evidence only within its actual
source/artifact/environment scope. Existing unresolved internal checks and the
historical evidence gap remain explicit; they are not erased by provider deferral.
The existing confirmation boundary and no-unreviewed-execution policy remain.

## Bounded registration cleanup — September 19, 2026

The separately authorized cleanup removes the launcher's `android.app.shortcuts`
metadata reference from the shipping Android manifest. `shortcuts.xml`, its query
resources and the original mapping/registration/candidate contracts remain
unchanged historical foundations, not active provider registration or proof of
approval. No dynamic shortcut publisher is introduced. Regression checks reject
registration or fulfillment intent filters in every app source-set manifest and
reject dynamic shortcut publication calls in retained application code.

This removes discovery registration, not the exported launcher or its explicit
review-only intent handling. MainActivity, the fail-closed resolver, replay
neutralization, review inbox, confirmation, timer/queue owners, in-app voice,
Apple integrations, dependencies and permissions remain unchanged. It does not
prevent another app from explicitly addressing the existing activity; such input
continues through the existing validation and review boundary.

README and roadmap current-state claims now describe external invocation as
deferred and the registration as detached. Historical phase contracts are not
rewritten into passes. No external store listing or provider account was inspected
or edited; final distribution disclosures and signed-artifact checks remain
release work. No AppFunctions or Google Home implementation is introduced.

The change is isolated on `phase-218-assistant-release-cleanup`, based on the
verified Phase 218 merge `f5899fc`. Source-level checks can verify this exact
manifest deletion and preservation boundary; Flutter regressions/analysis and
the native merged-manifest/resource check must pass before integration. No
release qualification is inferred from the cleanup itself.

Initial local checks passed: parsed manifest comparison found exactly one
registration removal and no permission/component/intent-filter changes; all app
source-set manifests omit the metadata; runtime code, resources, dependency files
and historical contracts match the baseline. Four synthetic merged-manifest
fixtures passed (accept detached registration; reject restored registration,
missing launcher and missing output). Shell syntax and whitespace checks passed.
Subsequent normal-Terminal verification completed both local gates using the
existing `tool/verify_soundscapes.sh` workflow:

- `phase218-verification-fjxKLa`: 80 focused tests and all 1,343 application
  tests passed; Flutter analysis reported no issues. Formatting and whitespace
  checks passed. The formatter adjusted only the two edited test files.
- `phase218-verification-OGGBch`: Android compilation/resources completed in
  1 minute 30 seconds (301 tasks executed, five up-to-date). All 54 native tests
  passed across ten reports, with zero failures, errors or skipped tests. All
  three merged debug manifests retained the launcher and omitted the legacy
  registration; the saved manifests were independently inspected afterward.

No APK, signing or device action was requested. Existing Kotlin/Gradle warnings
did not fail the build and were not addressed by widening this cleanup. These
results establish local cleanup verification, not GitHub CI success or signed
release qualification. The production merged manifest remains a release-artifact
check; the inspected native build was debug. No extra build/sign/install pipeline
was introduced.

No candidate lock, historical result or approval flag is rewritten. No support
reply or EAP form is sent, no monitor is scheduled, and no commit, push, signing,
device action or distribution is authorized by this documentation update.
