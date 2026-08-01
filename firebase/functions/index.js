const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { onRequest } = require("firebase-functions/v2/https");
const functions = require("firebase-functions/v1");

initializeApp();

/**
 * Prefer Identity Platform blocking functions when available
 * (beforeUserCreated / beforeUserSignedIn). This onCreate fallback
 * covers projects without blocking functions.
 *
 * After signup, the iOS client must call getIDToken(forcingRefresh: true)
 * so the role claim is present for Supabase RLS.
 */
exports.processSignUp = functions.auth.user().onCreate(async (user) => {
  await getAuth().setCustomUserClaims(user.uid, {
    role: "authenticated",
  });
});

/** One-off / ops helper: backfill role claim for all users. Protect this in production. */
exports.backfillSupabaseRole = onRequest(async (_req, res) => {
  let nextPageToken;
  let updated = 0;
  do {
    const page = await getAuth().listUsers(1000, nextPageToken);
    await Promise.all(
      page.users.map(async (userRecord) => {
        const claims = userRecord.customClaims || {};
        if (claims.role === "authenticated") return;
        await getAuth().setCustomUserClaims(userRecord.uid, {
          ...claims,
          role: "authenticated",
        });
        updated += 1;
      })
    );
    nextPageToken = page.pageToken;
  } while (nextPageToken);
  res.json({ updated });
});
