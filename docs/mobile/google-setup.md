# Google Cloud Setup for SpendWise Mobile

Follow these steps to enable Google Sign-In, Drive backup, and Sheets sync for the Android app.

## 1. Create a Google Cloud project

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (e.g. `SpendWise Mobile`)
3. Enable APIs:
   - **Google Sheets API**
   - **Google Drive API**

## 2. Configure OAuth consent screen

1. Go to **APIs & Services → OAuth consent screen**
2. Choose **External** (or Internal if using Google Workspace)
3. Add app name: `SpendWise`
4. Add scopes:
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/drive.file`
5. Add your Google account as a test user (while in Testing mode)

## 3. Generate keystore in GitHub (no local setup)

1. Go to **Actions → Android Keystore Setup → Run workflow**
2. Enter a password (e.g. `MySecurePass123`) — use the same for key password if you want
3. Leave alias as `upload` → **Run workflow**
4. Open the run and expand:
   - **Print SHA-1 for Google OAuth** → copy the `SHA1:` line
   - **Print base64 for ANDROID_KEYSTORE_BASE64** → copy the long base64 string
5. Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The base64 string from step 4 |
| `KEYSTORE_PASSWORD` | The password you entered |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | The key password you entered |

Run this workflow **once**. Keep the same secrets forever — changing them changes the SHA-1.

## 4. Create Android OAuth client

1. Go to **APIs & Services → Google Auth Platform → Clients → Create client**
2. Application type: **Android**
3. Package name: `com.spendwise.mobile`
4. SHA-1: paste the value from **Android Keystore Setup** step 4

## 5. Build and get APK

1. **Actions → Build APK → Run workflow**
2. **Print release SHA-1** should now show the same SHA-1 (confirms secrets work)
3. Download **Artifacts → spendwise-apk** and install on your phone

## 6. Configure the app

The default spreadsheet is pre-configured in the app:

- Sheet ID: `1ObWgYGp928tIva0FvWZyIcFNvLRkkG0gTRHrgyQ9JbU`
- Tab gid: `1320698518` (`Sheet1`)

Ensure the Google account you sign in with has **Editor** access to that spreadsheet.

## 7. Download APK from GitHub Actions

Already covered in step 5 — artifact name is `spendwise-apk`.

## Troubleshooting

| Issue | Fix |
|---|---|
| Sign-in fails with error 10 | SHA-1 mismatch — verify OAuth client fingerprint |
| Sheets append fails 403 | Enable Sheets API; check spreadsheet sharing |
| Background sync not running | Disable battery optimization for SpendWise; use Sync now |

See also [sheet-mapping.md](./sheet-mapping.md) for column layout details.
