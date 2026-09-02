/// Google OAuth configuration baked in at build time via `--dart-define`.
///
/// Build APK workflow passes:
///   --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
class GoogleConfig {
  GoogleConfig._();

  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Must match Android OAuth client package name in Google Cloud Console.
  static const androidPackageName = 'com.spendwise.mobile';
}
