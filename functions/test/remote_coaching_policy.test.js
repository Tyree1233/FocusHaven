"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  PRO_SUBSCRIPTION_REQUIRED_MESSAGE,
  REMOTE_COACHING_DISABLED_MESSAGE,
  evaluateRemoteCoachingAccess,
} = require("../remote_coaching_policy");

test("requires authentication before revealing remote availability", () => {
  assert.deepEqual(
    evaluateRemoteCoachingAccess({ authenticated: false, enabled: false }),
    {
      code: "unauthenticated",
      message: "Sign in to use the remote Focus Coach.",
    },
  );
  assert.deepEqual(
    evaluateRemoteCoachingAccess({ authenticated: false, enabled: true }),
    {
      code: "unauthenticated",
      message: "Sign in to use the remote Focus Coach.",
    },
  );
});

test("fails closed unless the remote switch is strictly enabled", () => {
  for (const enabled of [undefined, null, false, 1, "true"]) {
    assert.deepEqual(
      evaluateRemoteCoachingAccess({ authenticated: true, enabled }),
      {
        code: "failed-precondition",
        message: REMOTE_COACHING_DISABLED_MESSAGE,
      },
    );
  }
});

test("allows only an enabled request with an active Pro claim", () => {
  assert.equal(
    evaluateRemoteCoachingAccess({
      authenticated: true,
      enabled: true,
      claims: {
        focusHavenProPlan: "monthly",
        focusHavenProExpiresAt: 2000,
      },
      nowSeconds: 1000,
    }),
    null,
  );
});

test("rejects missing malformed and expired Pro claims", () => {
  const invalidClaims = [
    undefined,
    null,
    [],
    "monthly",
    {},
    { focusHavenProPlan: "monthly" },
    {
      focusHavenProPlan: "monthly",
      focusHavenProExpiresAt: "2000",
    },
    {
      focusHavenProPlan: "monthly",
      focusHavenProExpiresAt: 1000,
    },
    {
      focusHavenProPlan: "monthly",
      focusHavenProExpiresAt: 999,
    },
    {
      focusHavenProPlan: "grandfatheredLifetime",
      focusHavenProExpiresAt: 2000,
    },
    {
      focusHavenProPlan: "weekly",
      focusHavenProExpiresAt: 2000,
    },
  ];

  for (const claims of invalidClaims) {
    assert.deepEqual(
      evaluateRemoteCoachingAccess({
        authenticated: true,
        enabled: true,
        claims,
        nowSeconds: 1000,
      }),
      {
        code: "permission-denied",
        message: PRO_SUBSCRIPTION_REQUIRED_MESSAGE,
      },
    );
  }
});

test("accepts only unexpired monthly and annual server claims", () => {
  for (const plan of ["monthly", "annual"]) {
    assert.equal(
      evaluateRemoteCoachingAccess({
        authenticated: true,
        enabled: true,
        claims: {
          focusHavenProPlan: plan,
          focusHavenProExpiresAt: 1001,
        },
        nowSeconds: 1000,
      }),
      null,
    );
  }
});
