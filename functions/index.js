"use strict";

const { getApps, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const {
  defineBoolean,
  defineInt,
  defineSecret,
  defineString,
} = require("firebase-functions/params");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const OpenAI = require("openai");

const {
  SYSTEM_INSTRUCTIONS,
  buildModelInput,
  normalizeCoachingRequest,
} = require("./coaching");
const { evaluateRemoteCoachingAccess } = require("./remote_coaching_policy");
const { consumeRemoteCoachingQuota } = require("./remote_coaching_quota");
const {
  deleteFocusHavenAccount,
  evaluateAccountDeletionAccess,
} = require("./account_deletion");
const {
  PRIVATE_DIAGNOSTIC_EVENT,
  buildPrivateDiagnostic,
} = require("./private_diagnostics");

if (getApps().length === 0) initializeApp();
const firestore = getFirestore();
const auth = getAuth();

const openAiApiKey = defineSecret("OPENAI_API_KEY");
const openAiModel = defineString("OPENAI_MODEL", {
  default: "gpt-5.6-terra",
  description: "OpenAI model used by the FocusHaven coaching responder.",
});
const remoteCoachingEnabled = defineBoolean("REMOTE_COACHING_ENABLED", {
  default: false,
  description: "Emergency server-side switch for remote Focus Coach calls.",
});
const remoteCoachingGlobalMonthlyLimit = defineInt(
  "REMOTE_COACHING_GLOBAL_MONTHLY_LIMIT",
  {
    default: 1000,
    description:
      "Hard server-wide limit for enhanced coaching replies per UTC month.",
  },
);

exports.deleteFocusHavenAccount = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
    minInstances: 0,
    maxInstances: 10,
    concurrency: 20,
    enforceAppCheck: true,
    consumeAppCheckToken: true,
  },
  async (request) => {
    const accessFailure = evaluateAccountDeletionAccess({
      authContext: request.auth,
    });
    if (accessFailure === "unauthenticated") {
      throw new HttpsError(
        "unauthenticated",
        "A signed-in FocusHaven account is required.",
      );
    }
    if (accessFailure === "anonymous") {
      throw new HttpsError(
        "failed-precondition",
        "Anonymous guest identities are replaced locally, not deleted as cloud accounts.",
      );
    }
    if (accessFailure === "recent-login-required") {
      throw new HttpsError(
        "failed-precondition",
        "A recent provider verification is required before account deletion.",
      );
    }

    try {
      return await deleteFocusHavenAccount({
        firestore,
        auth,
        uid: request.auth.uid,
      });
    } catch (error) {
      logger.error("FocusHaven account deletion failed.", {
        ...buildPrivateDiagnostic(
          PRIVATE_DIAGNOSTIC_EVENT.ACCOUNT_DELETION,
          {error},
        ),
      });
      throw new HttpsError(
        "internal",
        "FocusHaven could not confirm complete account deletion.",
      );
    }
  },
);

exports.focusCoach = onCall(
  {
    region: "us-central1",
    secrets: [openAiApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
    minInstances: 0,
    maxInstances: 10,
    concurrency: 20,
    enforceAppCheck: true,
    consumeAppCheckToken: true,
  },
  async (request) => {
    const accessFailure = evaluateRemoteCoachingAccess({
      authenticated: Boolean(request.auth),
      claims: request.auth?.token ?? null,
      enabled: remoteCoachingEnabled.value(),
      nowSeconds: Math.floor(Date.now() / 1000),
    });
    if (accessFailure) {
      throw new HttpsError(
        accessFailure.code,
        accessFailure.message,
      );
    }

    let coachingRequest;
    try {
      coachingRequest = normalizeCoachingRequest(request.data);
    } catch (error) {
      throw new HttpsError(
        "invalid-argument",
        error instanceof Error ? error.message : "Invalid coaching request.",
      );
    }

    let quota;
    try {
      quota = await consumeRemoteCoachingQuota({
        firestore,
        uid: request.auth.uid,
        globalLimit: remoteCoachingGlobalMonthlyLimit.value(),
      });
    } catch (error) {
      logger.error("Focus Coach quota reservation failed.", {
        ...buildPrivateDiagnostic(
          PRIVATE_DIAGNOSTIC_EVENT.QUOTA_RESERVATION,
          {error},
        ),
      });
      throw new HttpsError(
        "unavailable",
        "Focus Coach usage could not be verified right now.",
      );
    }
    if (!quota.allowed) {
      if (quota.reason === "global-limit") {
        logger.warn("Focus Coach global monthly limit reached.", {
          ...buildPrivateDiagnostic(
            PRIVATE_DIAGNOSTIC_EVENT.GLOBAL_QUOTA,
            {period: quota.period},
          ),
        });
        throw new HttpsError(
          "resource-exhausted",
          "Enhanced Focus Coach is temporarily unavailable.",
          {
            reason: "global-budget-exhausted",
            period: quota.period,
          },
        );
      }
      throw new HttpsError(
        "resource-exhausted",
        "Your enhanced coaching allowance will renew next month.",
        {
          reason: "monthly-quota-exhausted",
          period: quota.period,
        },
      );
    }

    try {
      const client = new OpenAI({
        apiKey: openAiApiKey.value(),
        timeout: 25000,
        maxRetries: 1,
      });
      const response = await client.responses.create({
        model: openAiModel.value(),
        instructions: SYSTEM_INSTRUCTIONS,
        input: buildModelInput(coachingRequest),
        reasoning: { effort: "low" },
        max_output_tokens: 400,
        store: false,
      });
      const text = response.output_text?.trim();
      if (!text) throw new Error("OpenAI returned an empty response.");
      return {
        text,
        usage: {
          limit: quota.limit,
          period: quota.period,
          remaining: quota.remaining,
        },
      };
    } catch (error) {
      const status = Number.isInteger(error?.status) ? error.status : null;
      logger.error("Focus Coach provider request failed.", {
        ...buildPrivateDiagnostic(
          PRIVATE_DIAGNOSTIC_EVENT.PROVIDER_REQUEST,
          {status},
        ),
      });
      throw new HttpsError(
        status === 429 ? "resource-exhausted" : "unavailable",
        "Focus Coach is temporarily unavailable.",
        { reason: "provider-unavailable" },
      );
    }
  },
);
