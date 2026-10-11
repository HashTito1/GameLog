# Admin setup

Admin roles are stored in a single Firestore document, `admins/list`:

```json
{
  "superAdminId": "<firebase auth uid of the super admin>",
  "adminIds": ["<same uid>", "<other admin uids>..."]
}
```

Roles are keyed by **Firebase Auth uid**, never by username (usernames can be
changed by users). `firestore.rules` enforces this server-side:

- Nobody can create or delete `admins/list` from the app.
- Only the super admin can update it, and cannot change `superAdminId` or
  remove themselves from `adminIds`.

## First-time setup

1. Sign up in the app with the account that should be super admin.
2. In the Firebase console, open **Authentication → Users** and copy that
   account's **User UID**.
3. Open **Firestore Database**, create collection `admins`, document `list`,
   with fields:
   - `superAdminId` (string): the UID
   - `adminIds` (array): one string element, the same UID
4. Open the admin app (`run_admin_app.bat`) and sign in.

If `admins/list` already exists, check that it has a `superAdminId` field
matching your UID; older versions of the app could create it without one.

## Adding more admins

Use **User management** in the admin app while signed in as the super admin.
