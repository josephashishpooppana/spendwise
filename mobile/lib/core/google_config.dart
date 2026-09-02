/// Google OAuth configuration baked in at build time via `--dart-define`.
///
/// Local builds: set `GOOGLE_WEB_CLIENT_ID` in `mobile/.env`, then run
/// `bash scripts/load-dart-defines.sh` (or use the Build APK workflow).
class GoogleConfig {
  GoogleConfig._();

  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Must match Android OAuth client package name in Google Cloud Console.
  static const androidPackageName = 'com.spendwise.mobile';
}
