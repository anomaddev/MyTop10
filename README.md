# MyTop10

Native SwiftUI iOS app for ranking and sharing Top 10 lists.

**Auth:** Firebase Authentication (Phone + Password)  
**Data:** Supabase (Postgres + Storage + RLS)  
**Ads:** Google AdMob

## Features

- Onboarding: Welcome → Phone OTP → Profile (avatar, name, username, strong password) → Location & Notifications
- Bottom tabs: My Lists · Categories · Create · Discover
- Profile bubble for edit profile / sign out
- Top 10 create, edit, drag-reorder
- Upvote, downvote, bookmark
- Followers / following
- Map pins on list items
- AdMob banner + interstitial placements

## Quick start

1. Follow **[SETUP.md](SETUP.md)** to create Firebase + Supabase and wire keys.
2. Open `MyTop10.xcodeproj` in Xcode 15+.
3. Set your signing team and run on a simulator or device.

## Project layout

```
MyTop10/                 SwiftUI app source
MyTop10.xcodeproj/       Xcode project (SPM: Firebase, Supabase, AdMob)
supabase/migrations/     Postgres schema + RLS
firebase/functions/      Sets role:authenticated claim for Supabase
SETUP.md                 Full Firebase + Supabase setup checklist
project.yml              Optional XcodeGen spec
```

## Firebase ↔ Supabase

The app sends Firebase ID tokens to Supabase via `accessToken`. A Cloud Function attaches `{ "role": "authenticated" }` to each user. RLS resolves the user with `auth.jwt() ->> 'sub'` (Firebase UID text), not `auth.uid()`.
