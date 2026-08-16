"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
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

test("allows an authenticated request only when explicitly enabled", () => {
  assert.equal(
    evaluateRemoteCoachingAccess({ authenticated: true, enabled: true }),
    null,
  );
});
