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

## 3. GitHub Secrets (one-time)

Add these repository secrets under **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` keystore file |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |

### Create a release keystore (if you do not have one)

```powershell
keytool -genkey -v -keystore release.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Remember the passwords and alias — you need them for the GitHub secrets.

### Encode keystore for GitHub

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) | Set-Clipboard
```

Paste the clipboard value as `ANDROID_KEYSTORE_BASE64`.

## 4. Get SHA-1 from GitHub Actions

1. Go to **Actions → Build APK → Run workflow**
2. Open the workflow run
3. Expand **Print release SHA-1 (for Google OAuth)**
4. Copy the line that starts with `SHA1:` (between the `===` markers)

If the step says **SHA-1 not available**, the repository secrets from step 3 are missing — add them and re-run.

## 5. Create Android OAuth client

1. Go to **APIs & Services → Google Auth Platform → Clients → Create client**
2. Application type: **Android**
3. Package name: `com.spendwise.mobile`
4. SHA-1 certificate fingerprint: paste the value from step 4

## 6. Configure the app

The default spreadsheet is pre-configured in the app:

- Sheet ID: `1ObWgYGp928tIva0FvWZyIcFNvLRkkG0gTRHrgyQ9JbU`
- Tab gid: `1320698518` (`Sheet1`)

Ensure the Google account you sign in with has **Editor** access to that spreadsheet.

## 7. Download APK from GitHub Actions

1. Push to `main` or run **Build APK** workflow manually
2. Open the workflow run → **Artifacts** → download `spendwise-apk`
3. Install on your Android device

## Troubleshooting

| Issue | Fix |
|---|---|
| Sign-in fails with error 10 | SHA-1 mismatch — verify OAuth client fingerprint |
| Sheets append fails 403 | Enable Sheets API; check spreadsheet sharing |
| Background sync not running | Disable battery optimization for SpendWise; use Sync now |

See also [sheet-mapping.md](./sheet-mapping.md) for column layout details.
