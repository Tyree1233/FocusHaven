"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  PRIVATE_DIAGNOSTIC_EVENT,
  buildPrivateDiagnostic,
  classifyPrivateError,
  normalizeProviderStatus,
  normalizeQuotaPeriod,
} = require("../private_diagnostics");

test("quota diagnostics expose only event and coarse error kind", () => {
  const error = new TypeError("private coaching text and account@example.com");
  error.uid = "private-user-id";
  error.request_id = "provider-request-id";

  const payload = buildPrivateDiagnostic(
    PRIVATE_DIAGNOSTIC_EVENT.QUOTA_RESERVATION,
    {error},
  );

  assert.deepEqual(payload, {
    diagnosticEvent: "coach.quota_reservation",
    errorKind: "type",
  });
  const encoded = JSON.stringify(payload);
  assert.doesNotMatch(encoded, /private|account|uid|request/i);
});

test("account deletion diagnostics expose no account data", () => {
  const error = new Error("account@example.com private-user-id");
  error.uid = "private-user-id";
  error.email = "account@example.com";

  const payload = buildPrivateDiagnostic(
    PRIVATE_DIAGNOSTIC_EVENT.ACCOUNT_DELETION,
    {error},
  );

  assert.deepEqual(payload, {
    diagnosticEvent: "account.deletion",
    errorKind: "other",
  });
  assert.doesNotMatch(JSON.stringify(payload), /email|uid|private-user/i);
});

test("unknown errors never copy attacker-controlled properties", () => {
  const privateError = {
    message: "journal reflection",
    prompt: "private coaching prompt",
    reply: "private coaching reply",
    email: "account@example.com",
    uid: "private-user-id",
    request_id: "provider-request-id",
    status: 503,
  };

  assert.equal(classifyPrivateError(privateError), "other");
  assert.deepEqual(
    buildPrivateDiagnostic(PRIVATE_DIAGNOSTIC_EVENT.QUOTA_RESERVATION, {
      error: privateError,
    }),
    {
      diagnosticEvent: "coach.quota_reservation",
      errorKind: "other",
    },
  );
});

test("provider status is bounded to an HTTP failure code", () => {
  assert.equal(normalizeProviderStatus(429), 429);
  assert.equal(normalizeProviderStatus(503), 503);
  assert.equal(normalizeProviderStatus(200), null);
  assert.equal(normalizeProviderStatus(600), null);
  assert.equal(normalizeProviderStatus("503"), null);

  assert.deepEqual(
    buildPrivateDiagnostic(PRIVATE_DIAGNOSTIC_EVENT.PROVIDER_REQUEST, {
      status: 503,
      request_id: "must-not-be-copied",
      uid: "must-not-be-copied",
    }),
    {
      diagnosticEvent: "coach.provider_request",
      providerStatus: 503,
    },
  );
});

test("quota period accepts only a UTC year-month value", () => {
  assert.equal(normalizeQuotaPeriod("2026-08"), "2026-08");
  assert.equal(normalizeQuotaPeriod("2026-13"), null);
  assert.equal(normalizeQuotaPeriod("2026-8"), null);
  assert.equal(normalizeQuotaPeriod("account@example.com"), null);

  assert.deepEqual(
    buildPrivateDiagnostic(PRIVATE_DIAGNOSTIC_EVENT.GLOBAL_QUOTA, {
      period: "2026-08",
      task: "must-not-be-copied",
    }),
    {
      diagnosticEvent: "coach.global_quota",
      period: "2026-08",
    },
  );
});

test("unknown diagnostic events are rejected", () => {
  assert.throws(
    () => buildPrivateDiagnostic("arbitrary.private.event", {}),
    /Unknown private diagnostic event/,
  );
});
