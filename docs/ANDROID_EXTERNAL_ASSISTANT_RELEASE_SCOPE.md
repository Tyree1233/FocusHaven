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

## Release follow-up — not implemented by this note

Before first release, review the legacy Android App Actions registration,
metadata and user-facing/store claims. Prepare a narrowly scoped change so the
release does not expose or advertise unavailable integration, while preserving
in-app voice and review behavior. This decision does not itself disable or remove
the current registration. That code/configuration change needs its own scoped
implementation and regression verification.

No candidate lock, historical result or approval flag is rewritten. No support
reply or EAP form is sent, no monitor is scheduled, and no commit, push, signing,
device action or distribution is authorized by this documentation update.
