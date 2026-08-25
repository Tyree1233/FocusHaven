"use strict";

const APP_CHECK_REPLAY_MESSAGE =
  "A fresh protected FocusHaven request is required.";

function evaluateAppCheckReplay(appContext) {
  if (appContext?.alreadyConsumed === true) {
    return {
      code: "failed-precondition",
      message: APP_CHECK_REPLAY_MESSAGE,
    };
  }
  return null;
}

module.exports = {
  APP_CHECK_REPLAY_MESSAGE,
  evaluateAppCheckReplay,
};
