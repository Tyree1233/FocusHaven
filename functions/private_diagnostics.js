"use strict";

const PRIVATE_DIAGNOSTIC_EVENT = Object.freeze({
  ACCOUNT_DELETION: "account.deletion",
  QUOTA_RESERVATION: "coach.quota_reservation",
  GLOBAL_QUOTA: "coach.global_quota",
  PROVIDER_REQUEST: "coach.provider_request",
});

const ALLOWED_EVENTS = new Set(Object.values(PRIVATE_DIAGNOSTIC_EVENT));

function classifyPrivateError(error) {
  return error instanceof TypeError ? "type" : "other";
}

function normalizeProviderStatus(value) {
  return Number.isInteger(value) && value >= 400 && value <= 599 ? value : null;
}

function normalizeQuotaPeriod(value) {
  return typeof value === "string" && /^\d{4}-(0[1-9]|1[0-2])$/.test(value) ?
    value :
    null;
}

/**
 * Builds a bounded structured log payload from an explicit event contract.
 *
 * This function intentionally ignores every property except the specific,
 * normalized fields handled below. Never spread an error or caller-provided
 * object into a diagnostic payload.
 *
 * @param {string} event stable allowlisted event code
 * @param {{error?: unknown, status?: unknown, period?: unknown}} details
 * @return {{diagnosticEvent: string, errorKind?: string,
 *   providerStatus?: number, period?: string}}
 */
function buildPrivateDiagnostic(event, details = {}) {
  if (!ALLOWED_EVENTS.has(event)) {
    throw new TypeError("Unknown private diagnostic event.");
  }

  const payload = {diagnosticEvent: event};
  if (
    event === PRIVATE_DIAGNOSTIC_EVENT.ACCOUNT_DELETION ||
    event === PRIVATE_DIAGNOSTIC_EVENT.QUOTA_RESERVATION
  ) {
    payload.errorKind = classifyPrivateError(details.error);
  }
  if (event === PRIVATE_DIAGNOSTIC_EVENT.GLOBAL_QUOTA) {
    const period = normalizeQuotaPeriod(details.period);
    if (period !== null) payload.period = period;
  }
  if (event === PRIVATE_DIAGNOSTIC_EVENT.PROVIDER_REQUEST) {
    const status = normalizeProviderStatus(details.status);
    if (status !== null) payload.providerStatus = status;
  }
  return payload;
}

module.exports = {
  PRIVATE_DIAGNOSTIC_EVENT,
  buildPrivateDiagnostic,
  classifyPrivateError,
  normalizeProviderStatus,
  normalizeQuotaPeriod,
};
