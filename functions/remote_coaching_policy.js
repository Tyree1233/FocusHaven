"use strict";

const REMOTE_COACHING_DISABLED_MESSAGE =
  "Enhanced Focus Coach is not available right now.";

function evaluateRemoteCoachingAccess({ authenticated, enabled }) {
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
  return null;
}

module.exports = {
  REMOTE_COACHING_DISABLED_MESSAGE,
  evaluateRemoteCoachingAccess,
};
