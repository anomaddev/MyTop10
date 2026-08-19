/**
 * Optional Identity Platform blocking functions.
 * Prefer these over auth.user().onCreate when Identity Platform is enabled,
 * so the first ID token already includes role: authenticated.
 *
 * Deploy alongside index.js (or replace processSignUp) after enabling
 * Identity Platform blocking functions in the Firebase console.
 */
const {
  beforeUserCreated,
  beforeUserSignedIn,
} = require("firebase-functions/v2/identity");

exports.beforecreated = beforeUserCreated((event) => ({
  customClaims: {
    role: "authenticated",
  },
}));

exports.beforesignedin = beforeUserSignedIn((event) => ({
  customClaims: {
    role: "authenticated",
  },
}));
