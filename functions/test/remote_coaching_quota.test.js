"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  REMOTE_COACHING_USAGE_COLLECTION,
  consumeRemoteCoachingQuota,
  quotaDocumentId,
  utcMonthKey,
} = require("../remote_coaching_quota");

class FakeFirestore {
  constructor(initial = new Map()) {
    this.records = new Map(initial);
    this.lastCollection = null;
    this.lastDocumentId = null;
  }

  collection(name) {
    this.lastCollection = name;
    return {
      doc: (id) => {
        this.lastDocumentId = id;
        return { id };
      },
    };
  }

  async runTransaction(callback) {
    return callback({
      get: async (reference) => {
        const value = this.records.get(reference.id);
        return {
          exists: value !== undefined,
          data: () => value,
        };
      },
      set: (reference, value) => {
        this.records.set(reference.id, structuredClone(value));
      },
    });
  }
}

test("uses UTC calendar months for quota periods", () => {
  assert.equal(utcMonthKey(new Date("2026-01-31T23:59:59Z")), "2026-01");
  assert.equal(utcMonthKey(new Date("2026-02-01T00:00:00Z")), "2026-02");
});

test("reserves usage without storing a raw user ID", async () => {
  const firestore = new FakeFirestore();
  const now = new Date("2026-08-16T12:00:00Z");

  const result = await consumeRemoteCoachingQuota({
    firestore,
    uid: "private-user-id",
    now,
  });

  assert.deepEqual(result, {
    allowed: true,
    limit: 120,
    period: "2026-08",
    remaining: 119,
  });
  assert.equal(firestore.lastCollection, REMOTE_COACHING_USAGE_COLLECTION);
  assert.doesNotMatch(firestore.lastDocumentId, /private-user-id/);
  assert.deepEqual(firestore.records.get(firestore.lastDocumentId), {
    period: "2026-08",
    updatedAt: now.toISOString(),
    used: 1,
  });
});

test("stops atomically reserving usage at the configured limit", async () => {
  const firestore = new FakeFirestore();
  const input = {
    firestore,
    uid: "quota-user",
    now: new Date("2026-08-16T12:00:00Z"),
    limit: 2,
  };

  assert.deepEqual(await consumeRemoteCoachingQuota(input), {
    allowed: true,
    limit: 2,
    period: "2026-08",
    remaining: 1,
  });
  assert.deepEqual(await consumeRemoteCoachingQuota(input), {
    allowed: true,
    limit: 2,
    period: "2026-08",
    remaining: 0,
  });
  assert.deepEqual(await consumeRemoteCoachingQuota(input), {
    allowed: false,
    limit: 2,
    period: "2026-08",
    remaining: 0,
  });
  assert.equal(firestore.records.get(firestore.lastDocumentId).used, 2);
});

test("fails closed when persisted quota state is malformed", async () => {
  const uid = "damaged-user";
  const period = "2026-08";
  const documentId = quotaDocumentId(uid, period);
  const firestore = new FakeFirestore(
    new Map([[documentId, { period, used: "1" }]]),
  );

  await assert.rejects(
    consumeRemoteCoachingQuota({
      firestore,
      uid,
      now: new Date("2026-08-16T12:00:00Z"),
    }),
    /quota state is invalid/,
  );
});

test("rejects invalid quota dependencies and limits", async () => {
  await assert.rejects(
    consumeRemoteCoachingQuota({ firestore: null, uid: "user" }),
    /Firestore quota store/,
  );
  await assert.rejects(
    consumeRemoteCoachingQuota({
      firestore: new FakeFirestore(),
      uid: "user",
      limit: 0,
    }),
    /positive integer quota limit/,
  );
  await assert.rejects(
    consumeRemoteCoachingQuota({
      firestore: new FakeFirestore(),
      uid: "",
    }),
    /authenticated user ID/,
  );
  await assert.rejects(
    consumeRemoteCoachingQuota({
      firestore: new FakeFirestore(),
      uid: "user",
      now: new Date("invalid"),
    }),
    /valid quota date/,
  );
});
