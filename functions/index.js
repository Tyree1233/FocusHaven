"use strict";

const {
  defineBoolean,
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

const openAiApiKey = defineSecret("OPENAI_API_KEY");
const openAiModel = defineString("OPENAI_MODEL", {
  default: "gpt-5.6-terra",
  description: "OpenAI model used by the FocusHaven coaching responder.",
});
const remoteCoachingEnabled = defineBoolean("REMOTE_COACHING_ENABLED", {
  default: false,
  description: "Emergency server-side switch for remote Focus Coach calls.",
});

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
      return { text };
    } catch (error) {
      const status = Number.isInteger(error?.status) ? error.status : null;
      logger.error("Focus Coach provider request failed.", {
        authenticated: true,
        providerStatus: status,
        providerRequestId: error?.request_id ?? null,
      });
      throw new HttpsError(
        status === 429 ? "resource-exhausted" : "unavailable",
        "Focus Coach is temporarily unavailable.",
      );
    }
  },
);
