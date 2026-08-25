"use strict";

const { FieldPath } = require("firebase-admin/firestore");

const {
  REMOTE_COACHING_USAGE_COLLECTION,
  quotaDocumentPrefix,
} = require("./remote_coaching_quota");

const MAX_PERSONAL_QUOTA_DOCUMENTS = 120;
const MAX_REAUTHENTICATION_AGE_SECONDS = 5 * 60;

function evaluateAccountDeletionAccess({
  authContext,
  nowSeconds = Math.floor(Date.now() / 1000),
  maxAgeSeconds = MAX_REAUTHENTICATION_AGE_SECONDS,
}) {
  if (!Number.isInteger(nowSeconds) || nowSeconds < 0) {
    throw new TypeError("A valid deletion-request time is required.");
  }
  if (!Number.isInteger(maxAgeSeconds) || maxAgeSeconds <= 0) {
    throw new TypeError("A positive reauthentication age is required.");
  }
  if (!authContext) return "unauthenticated";
  if (authContext.token?.firebase?.sign_in_provider === "anonymous") {
    return "anonymous";
  }
  const authTime = authContext.token?.auth_time;
  if (
    !Number.isInteger(authTime) ||
    authTime > nowSeconds ||
    nowSeconds - authTime > maxAgeSeconds
  ) {
    return "recent-login-required";
  }
  return null;
}

async function deleteFocusHavenAccount({ firestore, auth, uid }) {
  if (!firestore || typeof firestore.batch !== "function") {
    throw new TypeError("A Firestore account store is required.");
  }
  if (!auth || typeof auth.deleteUser !== "function") {
    throw new TypeError("A Firebase Auth administrator is required.");
  }
  if (typeof uid !== "string" || uid.length === 0) {
    throw new TypeError("An authenticated user ID is required.");
  }

  const prefix = quotaDocumentPrefix(uid);
  const quotaSnapshot = await firestore
    .collection(REMOTE_COACHING_USAGE_COLLECTION)
    .where(FieldPath.documentId(), ">=", prefix)
    .where(FieldPath.documentId(), "<", `${prefix}\uf8ff`)
    .limit(MAX_PERSONAL_QUOTA_DOCUMENTS + 1)
    .get();
  if (quotaSnapshot.size > MAX_PERSONAL_QUOTA_DOCUMENTS) {
    throw new Error("Account data exceeds the bounded deletion contract.");
  }

  const batch = firestore.batch();
  batch.delete(firestore.collection("users").doc(uid));
  for (const document of quotaSnapshot.docs) {
    if (!document.id.startsWith(prefix)) {
      throw new Error("Account quota query returned an invalid document.");
    }
    batch.delete(document.ref);
  }
  await batch.commit();

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
  }

  return {
    deleted: true,
    deletedQuotaDocuments: quotaSnapshot.size,
  };
}

module.exports = {
  MAX_PERSONAL_QUOTA_DOCUMENTS,
  MAX_REAUTHENTICATION_AGE_SECONDS,
  deleteFocusHavenAccount,
  evaluateAccountDeletionAccess,
};
