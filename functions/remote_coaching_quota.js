"use strict";

const { createHash } = require("node:crypto");

const DEFAULT_MONTHLY_REMOTE_COACHING_LIMIT = 120;
const DEFAULT_GLOBAL_MONTHLY_REMOTE_COACHING_LIMIT = 1000;
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

function quotaDocumentPrefix(uid) {
  if (typeof uid !== "string" || uid.length === 0) {
    throw new TypeError("An authenticated user ID is required.");
  }
  return `${createHash("sha256").update(uid).digest("base64url")}-`;
}

function globalQuotaDocumentId(period) {
  return `global-${period}`;
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
  globalLimit,
}) {
  if (!firestore || typeof firestore.runTransaction !== "function") {
    throw new TypeError("A Firestore quota store is required.");
  }
  if (!Number.isInteger(limit) || limit <= 0) {
    throw new TypeError("A positive integer quota limit is required.");
  }
  if (
    globalLimit !== undefined &&
    (!Number.isInteger(globalLimit) || globalLimit <= 0)
  ) {
    throw new TypeError("A positive integer global quota limit is required.");
  }
  const period = utcMonthKey(now);
  const documentId = quotaDocumentId(uid, period);
  const reference = firestore
    .collection(REMOTE_COACHING_USAGE_COLLECTION)
    .doc(documentId);
  const globalReference = globalLimit === undefined
    ? null
    : firestore
      .collection(REMOTE_COACHING_USAGE_COLLECTION)
      .doc(globalQuotaDocumentId(period));

  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const used = readUsedCount(snapshot);
    const globalSnapshot = globalReference === null
      ? null
      : await transaction.get(globalReference);
    const globalUsed = globalSnapshot === null
      ? null
      : readUsedCount(globalSnapshot);

    if (globalUsed !== null && globalUsed >= globalLimit) {
      return {
        allowed: false,
        reason: "global-limit",
        limit,
        period,
        remaining: Math.max(limit - used, 0),
        globalLimit,
        globalRemaining: 0,
      };
    }
    if (used >= limit) {
      if (globalUsed === null) {
        return { allowed: false, limit, period, remaining: 0 };
      }
      return {
        allowed: false,
        reason: "user-limit",
        limit,
        period,
        remaining: 0,
        globalLimit,
        globalRemaining: globalLimit - globalUsed,
      };
    }

    const nextUsed = used + 1;
    transaction.set(reference, {
      period,
      updatedAt: now.toISOString(),
      used: nextUsed,
    });
    const result = {
      allowed: true,
      limit,
      period,
      remaining: limit - nextUsed,
    };
    if (globalReference === null || globalUsed === null) return result;

    const nextGlobalUsed = globalUsed + 1;
    transaction.set(globalReference, {
      period,
      scope: "global",
      updatedAt: now.toISOString(),
      used: nextGlobalUsed,
    });
    return {
      ...result,
      globalLimit,
      globalRemaining: globalLimit - nextGlobalUsed,
    };
  });
}

module.exports = {
  DEFAULT_GLOBAL_MONTHLY_REMOTE_COACHING_LIMIT,
  DEFAULT_MONTHLY_REMOTE_COACHING_LIMIT,
  REMOTE_COACHING_USAGE_COLLECTION,
  consumeRemoteCoachingQuota,
  globalQuotaDocumentId,
  quotaDocumentId,
  quotaDocumentPrefix,
  utcMonthKey,
};
