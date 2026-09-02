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

## 3. Create Android OAuth client

1. Go to **APIs & Services → Credentials → Create Credentials → OAuth client ID**
2. Application type: **Android**
3. Package name: `com.spendwise.mobile`
4. SHA-1 certificate fingerprint: get from GitHub Actions build log (see workflow) or local debug keystore:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

For release builds, use the SHA-1 from your release keystore (stored in GitHub Secrets).

## 4. Configure the app

The default spreadsheet is pre-configured in the app:

- Sheet ID: `1ObWgYGp928tIva0FvWZyIcFNvLRkkG0gTRHrgyQ9JbU`
- Tab gid: `1320698518` (`Sheet1`)

Ensure the Google account you sign in with has **Editor** access to that spreadsheet.

## 5. GitHub Secrets for signed APK

Add these repository secrets for release builds:

| Secret | Description |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` keystore file |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |

Generate base64 on Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) | Set-Clipboard
```

## 6. Download APK from GitHub Actions

1. Push to `main` or run **Flutter Android Build** workflow manually
2. Open the workflow run → **Artifacts** → download `spendwise-release-apk`
3. Install on your Android device

## Troubleshooting

| Issue | Fix |
|---|---|
| Sign-in fails with error 10 | SHA-1 mismatch — verify OAuth client fingerprint |
| Sheets append fails 403 | Enable Sheets API; check spreadsheet sharing |
| Background sync not running | Disable battery optimization for SpendWise; use Sync now |

See also [sheet-mapping.md](./sheet-mapping.md) for column layout details.
