# Security hardening, Flutter 3.47 / JDK 27 build, and a full UI pass

## Summary
- **Security:** no secrets in source, owner-only Firestore rules, admin roles by uid, emails off public profiles
- **Build:** Flutter 3.47, Gradle 9.8.1 (runs on JDK 27), AGP 9.1, Kotlin 2.4.10, real release signing
- **Features:** every "coming soon" item now works (reporting, moderation queues, admin logs, sharing, help and support, user guide, category search and sort)
- **UI pass:** each screen checked on an Android emulator; fixed wrong, mislabelled and fabricated data, plus broken filters

## Security
- IGDB and ImgBB keys move from source to `dart_defines.json` (git-ignored); RAWG removed (it was unused). `scripts/refresh_igdb_token.ps1` refreshes the 60-day IGDB token.
- `firestore.rules` rewritten:
  - Owner-only writes.
  - Likes are limited to adding or removing your own uid; counters are field-restricted.
  - Server-side ban checks.
  - New `reports` (anyone files, admins read) and append-only `admin_logs`.
- Admin and super-admin are checked by uid in `admins/list` and can't be bootstrapped from the client (see `docs/ADMIN_SETUP.md`). Previously the super admin was whoever had a particular username, and usernames weren't unique.
- Emails are no longer stored on public profiles, and are stripped from existing ones at next login. Usernames are unique at sign-up.
- Release signing via `android/key.properties`.

## Build
- Gradle 9.8.1 runs on JDK 27. AGP's jlink step can't handle JDK 27 yet, so compilation uses a JDK 25 toolchain (Android Studio's). Setup is in the README.
- AGP 9 changes:
  - `resValues` turned on explicitly for the flavor app names.
  - Removed `buildconfig` from `gradle.properties` and moved it to `buildFeatures`.
  - Removed `firebase-analytics`: it had no BoM and was unused.

## Data that was wrong or made up
| Where | Problem | Fix |
|---|---|---|
| Game page | Backlog/Playing counts were invented as 30% and 20% of reviews (the real query was always denied) | Replaced with IGDB score and friends who rated it |
| Home: friend reviews | Always "0": `whereIn` + `orderBy` needed a missing index | Chunked queries sorted in the app; cards show the game cover and title |
| Home: Popular / Trending / Best of year | A second `where` clause overrode the filters; re-releases and obscure titles; "New releases" was actually the Shooter genre | One `where` per query, originals only, rating-count floors, correct labels |
| Similar games | Genre slug never matched, so unrelated popular games | IGDB's curated `similar_games` list |
| Search filters | Platform used RAWG ids; rating, year and sort were ignored | IGDB platform names; all filters applied |
| Discover | Genre/platform filters did nothing | Removed |
| Settings | Privacy and notification switches were never saved; Profile Settings did nothing | Removed |
| Ratings | Editing a rating reset its likes, comments and date | Preserved |
| Library | Backlog and total counts disagreed with the lists | Same rules everywhere |

## Features (previously "coming soon")
- Report reviews and forum posts; in-app bug reports.
- Admin: content moderation (reviews, comments, reports), "reported" forum filter, open-report stats, system logs.
- Share reviews and profiles (`share_plus`).
- Help & Support: email, forum, bug report and user guide.
- Category screens: search and sort.

## UI
- Labelled bottom navigation.
- Clearer welcome copy.
- Game page header shows the full cover over a blurred backdrop.
- Search opens with browse shortcuts.
- Tidier profile actions.
- Unambiguous dates everywhere (e.g. "Sep 2, 2026").

## Before merging
- [x] **Rules and indexes deployed** (`firebase deploy --only firestore`, done Oct 12). Reports, admin logs, the collection-group review query and the composite indexes depend on it.
- [x] New IGDB access token in place and verified.
- [ ] Rotate the Twitch client secret and ImgBB key (both were in git history and/or shared).
- [ ] Set up `android/key.properties` before publishing a release.

## Testing
- `flutter analyze`: 0 errors
- `flutter test`: 11 passing (models, version comparison, updater APK choice)
- Built and run on an Android emulator (API 37); walked through Home, Discover, Search, Library, Profile, Game page, Notifications, Settings, Help & Support, Forum and Friends.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
