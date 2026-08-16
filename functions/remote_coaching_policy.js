"use strict";

const REMOTE_COACHING_DISABLED_MESSAGE =
  "Enhanced Focus Coach is not available right now.";
const PRO_SUBSCRIPTION_REQUIRED_MESSAGE =
  "An active FocusHaven Pro subscription is required.";
const PRO_SUBSCRIPTION_PLANS = new Set(["monthly", "annual"]);

function hasActiveProSubscription({ claims, nowSeconds }) {
  if (!claims || typeof claims !== "object" || Array.isArray(claims)) {
    return false;
  }
  const plan = claims.focusHavenProPlan;
  const expiresAt = claims.focusHavenProExpiresAt;
  return (
    PRO_SUBSCRIPTION_PLANS.has(plan) &&
    Number.isInteger(expiresAt) &&
    expiresAt > nowSeconds
  );
}

function evaluateRemoteCoachingAccess({
  authenticated,
  enabled,
  claims,
  nowSeconds = Math.floor(Date.now() / 1000),
}) {
  if (authenticated !== true) {
    return {
      code: "unauthenticated",
      message: "Sign in to use the remote Focus Coach.",
    };
  }
  if (enabled !== true) {
    return {
      code: "failed-precondition",
      message: REMOTE_COACHING_DISABLED_MESSAGE,
    };
  }
  if (!hasActiveProSubscription({ claims, nowSeconds })) {
    return {
      code: "permission-denied",
      message: PRO_SUBSCRIPTION_REQUIRED_MESSAGE,
    };
  }
  return null;
}

module.exports = {
  PRO_SUBSCRIPTION_REQUIRED_MESSAGE,
  REMOTE_COACHING_DISABLED_MESSAGE,
  evaluateRemoteCoachingAccess,
  hasActiveProSubscription,
};
