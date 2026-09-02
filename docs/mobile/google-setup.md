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

## 4. Create OAuth clients (Android + Web)

You need **two** OAuth clients in [Google Auth Platform → Clients](https://console.cloud.google.com/apis/credentials):

### A. Android client

1. **Create client** → Application type: **Android**
2. Package name: `com.spendwise.mobile` (must match exactly)
3. SHA-1: from **Android Keystore Setup** step 4 (or **Build APK → Print release SHA-1**)

### B. Web client (required for Sheets/Drive access)

1. **Create client** → Application type: **Web application**
2. Name: `SpendWise Web`
3. Copy the **Client ID** (ends with `.apps.googleusercontent.com`)
4. Configure using **either** method:

**Option A — `mobile/.env` (default in this repo)**

Edit `mobile/.env`:

```env
GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

This file is committed so **Build APK** picks it up automatically. Do not commit `client_secret*.json` files from Google Cloud.

**Option B — GitHub Actions secret**

| Secret | Value |
|---|---|
| `GOOGLE_WEB_CLIENT_ID` | Web client ID from step 3 |

Or paste the full `.env` file contents into secret `MOBILE_ENV`.

Re-run **Build APK** after configuring so the app receives the Web client ID at compile time.

## 5. Build and get APK

1. **Actions → Build APK → Run workflow**
2. **Print release SHA-1** should now show the same SHA-1 (confirms secrets work)
3. Download **Artifacts → spendwise-apk** and install on your phone

## 6. Configure the app

The default spreadsheet is pre-configured in the app:

- Sheet ID: `1ObWgYGp928tIva0FvWZyIcFNvLRkkG0gTRHrgyQ9JbU`
- Tab gid: `1320698518` (`Sheet1`)

Ensure the Google account you sign in with has **Editor** access to that spreadsheet.

## 7. Import existing sheet transactions into the app

1. **Settings → Sign in** (Google account with access to the sheet)
2. **Import from Google Sheet**
3. Confirm — this reads every row from `Sheet1` (from row 3) and creates local transactions
4. Account balances are recalculated from imported data

Use this once to pull in your history. After that, add new expenses in the app and use **Sync now** to append only new rows to the sheet.

## 8. Download APK from GitHub Actions

Already covered in step 5 — artifact name is `spendwise-apk`.

## Troubleshooting

| Issue | Fix |
|---|---|
| Sign-in fails with **error 10** | See [Fix error 10](#fix-error-10-sign_in_failed-code-10) below |
| Sheets append fails 403 | Enable Sheets API; check spreadsheet sharing |
| Background sync not running | Use **Sync now** in Settings |

See also [sheet-mapping.md](./sheet-mapping.md) for column layout details.

## When does the app ask for Google login?

**Not on app open.** SpendWise starts fully offline with local storage only.

Google sign-in happens only when you:

1. Open **Settings** (bottom nav)
2. Tap **Sign in** — choose your Gmail account
3. Tap **Sync now** — Google asks permission for **Google Sheets** and **Google Drive**

Your spreadsheet is already configured in the app (`Sheet1` in your Daily Expenses sheet). The signed-in Google account must have **Editor** access to that sheet.

## App closes immediately on open

1. **Rebuild with the latest code** — Run **Actions → Build APK**, uninstall the old app, install the new APK.
2. Recent fixes removed **Workmanager** (native crash on some phones), added a **startup bootstrap**, and fixed database race conditions.
3. If you see an in-app error screen instead of a crash, note the message and share it.
4. If it still closes with no message, check **Android Settings → Apps → SpendWise** and clear app data, then reopen.

## Fix error 10 (sign_in_failed code 10)

Error **10** means Google OAuth is misconfigured. Check **all** of these:

### 1. Package name must be `com.spendwise.mobile`

In Google Cloud → Android OAuth client, the package name must be exactly:

`com.spendwise.mobile`

Older APK builds used `com.spendwise.spendwise_mobile` — that causes error 10. **Rebuild and reinstall** the latest APK.

### 2. SHA-1 must match the APK you installed

1. Run **Actions → Build APK**
2. Open the **Print APK signing SHA-1** step in the workflow log
3. Copy the SHA-1 fingerprint
4. In Google Cloud → your **Android** OAuth client → add or update the SHA-1

If you skipped keystore setup, the APK uses a different certificate and sign-in will fail. Complete **Android Keystore Setup** first, add the four keystore secrets, then rebuild.

### 3. Add Web OAuth client + GitHub secret

Create a **Web application** OAuth client and set repository secret `GOOGLE_WEB_CLIENT_ID` to its Client ID. Rebuild the APK.

### 4. OAuth consent screen

- Add your Gmail as a **Test user** (while app is in Testing mode)
- Enable **Google Sheets API** and **Google Drive API**

### 5. After changing Google Cloud settings

Wait 5–10 minutes, then try **Settings → Sign out → Sign in** again.
