# MyTop10 Setup — Firebase + Supabase

Native SwiftUI app. Firebase Authentication owns identity. Supabase owns Postgres, Storage, and RLS.

## 1. Open the iOS project

1. On a Mac with Xcode 15+, clone this repo.
2. Open `MyTop10.xcodeproj`.
3. Set your **Team** under Signing & Capabilities.
4. (Optional) Regenerate the project after adding files:
   ```bash
   python3 scripts/generate_xcodeproj.py
   ```
   Or use XcodeGen: `brew install xcodegen && xcodegen generate` (see `project.yml`).

## 2. Firebase

1. Create a project at [Firebase Console](https://console.firebase.google.com).
2. Add an **iOS app** with bundle ID `com.anomaddev.MyTop10` (or change the bundle ID in Xcode to match).
3. Download `GoogleService-Info.plist` into `MyTop10/Resources/` and add it to the Xcode target.
4. Enable **Authentication → Sign-in method**:
   - Phone
   - Email/Password
5. For Phone Auth on device:
   - Upload APNs key in Firebase Project Settings → Cloud Messaging
   - Add test phone numbers under Authentication → Phone for Simulator
6. Blaze plan is required for Cloud Functions / some Phone Auth usage in production.
7. From `firebase/`:
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase use YOUR_FIREBASE_PROJECT_ID
   cd functions && npm install && cd ..
   firebase deploy --only functions
   ```
   The `processSignUp` function sets `{ role: "authenticated" }` on every new user so Supabase RLS works.

### Optional (recommended): Identity Platform blocking functions

If Identity Platform is enabled, prefer `beforeUserCreated` / `beforeUserSignedIn` blocking functions that return `customClaims: { role: "authenticated" }` so the claim exists on the first token. The app still force-refreshes the ID token after signup.

## 3. Supabase

1. Create a project at [Supabase Dashboard](https://supabase.com/dashboard).
2. **Authentication → Third-Party Auth → Firebase**
   - Enable Firebase
   - Enter your Firebase **Project ID** (same as in `GoogleService-Info.plist`)
3. Update `supabase/config.toml`:
   ```toml
   [auth.third_party.firebase]
   enabled = true
   project_id = "YOUR_FIREBASE_PROJECT_ID"
   ```
4. Run the schema (in order):
   - SQL Editor → run `supabase/migrations/20260801000000_init.sql`
   - Then run `supabase/migrations/20260801120000_item_enrichment.sql` (tags, photos, ratings, list sort order)
   - Or CLI: `supabase link` then `supabase db push`
5. Confirm Storage buckets `avatars` and `covers` exist (migration inserts them).
6. Copy **Project URL** and **anon/publishable key** into `MyTop10/Resources/Config.plist`.

## 4. App config

Copy and edit:

```bash
cp MyTop10/Resources/Config.example.plist MyTop10/Resources/Config.plist
```

Fill in:

| Key | Value |
|-----|--------|
| `SUPABASE_URL` | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anon/publishable key |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `ADMOB_*` | Leave Google test IDs until production |
| `PASSWORD_EMAIL_DOMAIN` | Keep `users.mytop10.app` (synthetic emails for password login) |

Do **not** commit real production secrets if the repo is public. `Config.plist` is gitignored when you add secrets; keep `Config.example.plist` as the template.

## 5. AdMob

1. Create an AdMob account and iOS app.
2. Create Banner + Interstitial units.
3. Set `GADApplicationIdentifier` / `ADMOB_APP_ID` build setting to your real App ID.
4. Put unit IDs in `Config.plist`.
5. Keep test IDs until you ship.

## 6. How Firebase Auth talks to Supabase

```
iOS → Firebase Phone / Email-Password → ID token (JWT)
                                         ↓
                         Supabase client accessToken callback
                                         ↓
                         Postgres role = claim "role": "authenticated"
                                         ↓
                         RLS uses public.firebase_uid() = jwt.sub
```

Critical details already implemented in code/SQL:

- Supabase client uses Firebase `getIDToken()` as `accessToken`
- Cloud Function sets `role: "authenticated"`
- App force-refreshes the token after signup / password link
- RLS uses `auth.jwt() ->> 'sub'` via `public.firebase_uid()` — never cast Firebase UIDs to UUID

## 7. Auth product behavior

| Step | Behavior |
|------|----------|
| Welcome → Phone | Firebase Phone OTP |
| Profile password | Links Email/Password using `phone+{digits}@users.mytop10.app` |
| Later Sign In | Phone + password (synthetic email) or OTP path during onboarding |
| Sign Out | Firebase `signOut()` + return to welcome |

## 8. Run

1. Select an iPhone simulator or device.
2. Build & Run in Xcode.
3. For Phone Auth in Simulator, use Firebase test phone numbers.
4. Complete: Welcome → Phone → OTP → Profile → Location/Notifications → Tabs.

## 9. What you still do manually

- Create Firebase + Supabase projects (cannot be done from this Linux agent environment)
- Drop in `GoogleService-Info.plist`
- Fill `Config.plist`
- Deploy Cloud Functions
- Enable Third-Party Firebase Auth in Supabase
- Apply SQL migration
- Set your Apple Developer Team + APNs key for real-device SMS
