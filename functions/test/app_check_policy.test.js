"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  APP_CHECK_REPLAY_MESSAGE,
  evaluateAppCheckReplay,
} = require("../app_check_policy");

test("accepts an unconsumed protected request", () => {
  assert.equal(evaluateAppCheckReplay({appId: "focus-haven"}), null);
  assert.equal(evaluateAppCheckReplay(null), null);
});

test("rejects an already-consumed App Check token", () => {
  assert.deepEqual(evaluateAppCheckReplay({alreadyConsumed: true}), {
    code: "failed-precondition",
    message: APP_CHECK_REPLAY_MESSAGE,
  });
});

test("does not confuse an explicit false signal with a replay", () => {
  assert.equal(evaluateAppCheckReplay({alreadyConsumed: false}), null);
});
