"use strict";

const { createHash } = require("node:crypto");

const DEFAULT_MONTHLY_REMOTE_COACHING_LIMIT = 120;
const REMOTE_COACHING_USAGE_COLLECTION = "remoteCoachingUsage";

function utcMonthKey(date) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    throw new TypeError("A valid quota date is required.");
  }
  const year = date.getUTCFullYear().toString().padStart(4, "0");
  const month = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  return `${year}-${month}`;
}

function quotaDocumentId(uid, period) {
  if (typeof uid !== "string" || uid.length === 0) {
    throw new TypeError("An authenticated user ID is required.");
  }
  const userHash = createHash("sha256").update(uid).digest("base64url");
  return `${userHash}-${period}`;
}

function readUsedCount(snapshot) {
  if (!snapshot.exists) return 0;
  const used = snapshot.data()?.used;
  if (!Number.isInteger(used) || used < 0) {
    throw new Error("Remote coaching quota state is invalid.");
  }
  return used;
}

async function consumeRemoteCoachingQuota({
  firestore,
  uid,
  now = new Date(),
  limit = DEFAULT_MONTHLY_REMOTE_COACHING_LIMIT,
}) {
  if (!firestore || typeof firestore.runTransaction !== "function") {
    throw new TypeError("A Firestore quota store is required.");
  }
  if (!Number.isInteger(limit) || limit <= 0) {
    throw new TypeError("A positive integer quota limit is required.");
  }
  const period = utcMonthKey(now);
  const documentId = quotaDocumentId(uid, period);
  const reference = firestore
    .collection(REMOTE_COACHING_USAGE_COLLECTION)
    .doc(documentId);

  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const used = readUsedCount(snapshot);
    if (used >= limit) {
      return { allowed: false, limit, period, remaining: 0 };
    }

    const nextUsed = used + 1;
    transaction.set(reference, {
      period,
      updatedAt: now.toISOString(),
      used: nextUsed,
    });
    return {
      allowed: true,
      limit,
      period,
      remaining: limit - nextUsed,
    };
  });
}

module.exports = {
  DEFAULT_MONTHLY_REMOTE_COACHING_LIMIT,
  REMOTE_COACHING_USAGE_COLLECTION,
  consumeRemoteCoachingQuota,
  quotaDocumentId,
  utcMonthKey,
};
