"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  MAX_PERSONAL_QUOTA_DOCUMENTS,
  deleteFocusHavenAccount,
  evaluateAccountDeletionAccess,
} = require("../account_deletion");
const {
  REMOTE_COACHING_USAGE_COLLECTION,
  globalQuotaDocumentId,
  quotaDocumentId,
} = require("../remote_coaching_quota");

class FakeFirestore {
  constructor(initial = new Map()) {
    this.records = new Map(initial);
    this.deletedPaths = [];
  }

  collection(name) {
    const firestore = this;
    const collection = {
      doc(id) {
        return { id, path: `${name}/${id}` };
      },
      where(_field, operator, value) {
        const filters = [[operator, value]];
        const query = {
          where(_nextField, nextOperator, nextValue) {
            filters.push([nextOperator, nextValue]);
            return query;
          },
          limit(maximum) {
            return {
              async get() {
                const lower = filters.find(([item]) => item === ">=")?.[1];
                const upper = filters.find(([item]) => item === "<")?.[1];
                const docs = [...firestore.records.keys()]
                  .filter((path) => path.startsWith(`${name}/`))
                  .map((path) => ({
                    id: path.substring(name.length + 1),
                    path,
                  }))
                  .filter((document) =>
                    document.id >= lower && document.id < upper
                  )
                  .slice(0, maximum)
                  .map((document) => ({
                    id: document.id,
                    ref: { id: document.id, path: document.path },
                  }));
                return { docs, size: docs.length };
              },
            };
          },
        };
        return query;
      },
    };
    return collection;
  }

  batch() {
    const pending = [];
    return {
      delete(reference) {
        pending.push(reference.path);
      },
      commit: async () => {
        for (const path of pending) {
          this.records.delete(path);
          this.deletedPaths.push(path);
        }
      },
    };
  }
}

class FakeAuth {
  constructor() {
    this.deletedUsers = [];
    this.failure = null;
  }

  async deleteUser(uid) {
    if (this.failure !== null) throw this.failure;
    this.deletedUsers.push(uid);
  }
}

test("requires a signed-in non-anonymous account with recent verification", () => {
  const nowSeconds = 1_787_500_000;
  const verified = {
    uid: "verified-user",
    token: {
      auth_time: nowSeconds - 60,
      firebase: { sign_in_provider: "google.com" },
    },
  };

  assert.equal(
    evaluateAccountDeletionAccess({ authContext: verified, nowSeconds }),
    null,
  );
  assert.equal(
    evaluateAccountDeletionAccess({ authContext: null, nowSeconds }),
    "unauthenticated",
  );
  assert.equal(
    evaluateAccountDeletionAccess({
      authContext: {
        ...verified,
        token: {
          ...verified.token,
          firebase: { sign_in_provider: "anonymous" },
        },
      },
      nowSeconds,
    }),
    "anonymous",
  );
  assert.equal(
    evaluateAccountDeletionAccess({
      authContext: {
        ...verified,
        token: { ...verified.token, auth_time: nowSeconds - 301 },
      },
      nowSeconds,
    }),
    "recent-login-required",
  );
});

test("deletes the account document and every personal quota record", async () => {
  const uid = "private-account-id";
  const otherUid = "other-account-id";
  const personalJanuary = quotaDocumentId(uid, "2026-01");
  const personalAugust = quotaDocumentId(uid, "2026-08");
  const otherAugust = quotaDocumentId(otherUid, "2026-08");
  const globalAugust = globalQuotaDocumentId("2026-08");
  const firestore = new FakeFirestore(new Map([
    [`users/${uid}`, { focusBackup: { focusSeconds: 1500 } }],
    [`${REMOTE_COACHING_USAGE_COLLECTION}/${personalJanuary}`, { used: 1 }],
    [`${REMOTE_COACHING_USAGE_COLLECTION}/${personalAugust}`, { used: 2 }],
    [`${REMOTE_COACHING_USAGE_COLLECTION}/${otherAugust}`, { used: 3 }],
    [`${REMOTE_COACHING_USAGE_COLLECTION}/${globalAugust}`, { used: 4 }],
  ]));
  const auth = new FakeAuth();

  const result = await deleteFocusHavenAccount({ firestore, auth, uid });

  assert.deepEqual(result, { deleted: true, deletedQuotaDocuments: 2 });
  assert.deepEqual(auth.deletedUsers, [uid]);
  assert.equal(firestore.records.has(`users/${uid}`), false);
  assert.equal(
    firestore.records.has(
      `${REMOTE_COACHING_USAGE_COLLECTION}/${personalJanuary}`,
    ),
    false,
  );
  assert.equal(
    firestore.records.has(
      `${REMOTE_COACHING_USAGE_COLLECTION}/${personalAugust}`,
    ),
    false,
  );
  assert.equal(
    firestore.records.has(`${REMOTE_COACHING_USAGE_COLLECTION}/${otherAugust}`),
    true,
  );
  assert.equal(
    firestore.records.has(`${REMOTE_COACHING_USAGE_COLLECTION}/${globalAugust}`),
    true,
  );
});

test("fails before mutation when personal quota data exceeds the bound", async () => {
  const uid = "oversized-account";
  const initial = new Map([[`users/${uid}`, { focusBackup: {} }]]);
  for (let index = 0; index <= MAX_PERSONAL_QUOTA_DOCUMENTS; index += 1) {
    initial.set(
      `${REMOTE_COACHING_USAGE_COLLECTION}/${quotaDocumentId(
        uid,
        `${index}`.padStart(7, "0"),
      )}`,
      { used: 1 },
    );
  }
  const firestore = new FakeFirestore(initial);
  const auth = new FakeAuth();

  await assert.rejects(
    deleteFocusHavenAccount({ firestore, auth, uid }),
    /bounded deletion contract/,
  );

  assert.equal(firestore.deletedPaths.length, 0);
  assert.equal(firestore.records.has(`users/${uid}`), true);
  assert.deepEqual(auth.deletedUsers, []);
});

test("an already-missing auth user is an idempotent success", async () => {
  const uid = "already-removed-account";
  const firestore = new FakeFirestore();
  const auth = new FakeAuth();
  auth.failure = { code: "auth/user-not-found" };

  const result = await deleteFocusHavenAccount({ firestore, auth, uid });

  assert.deepEqual(result, { deleted: true, deletedQuotaDocuments: 0 });
});

test("rejects invalid dependencies and anonymous identifiers", async () => {
  const firestore = new FakeFirestore();
  const auth = new FakeAuth();

  await assert.rejects(
    deleteFocusHavenAccount({ firestore: null, auth, uid: "user" }),
    /Firestore account store/,
  );
  await assert.rejects(
    deleteFocusHavenAccount({ firestore, auth: null, uid: "user" }),
    /Firebase Auth administrator/,
  );
  await assert.rejects(
    deleteFocusHavenAccount({ firestore, auth, uid: "" }),
    /authenticated user ID/,
  );
});
