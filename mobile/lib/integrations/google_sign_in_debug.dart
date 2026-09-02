import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spendwise_mobile/core/google_config.dart';

/// Formats Google Sign-In failures with config context for on-device debugging.
class GoogleSignInDebugReport {
  static String formatError(Object error, [StackTrace? stackTrace]) {
    final buffer = StringBuffer('=== Sign-in error ===\n');

    if (error is PlatformException) {
      buffer.writeln('Type: PlatformException');
      buffer.writeln('Code: ${error.code}');
      buffer.writeln('Message: ${error.message ?? '(null)'}');
      buffer.writeln('Details: ${_stringify(error.details)}');
      buffer.writeln('Stacktrace: ${error.stacktrace ?? '(null)'}');

      final hint = hintForPlatformException(error);
      if (hint != null) {
        buffer.writeln('');
        buffer.writeln('Interpretation:');
        buffer.writeln(hint);
      }
    } else {
      buffer.writeln('Type: ${error.runtimeType}');
      buffer.writeln('Message: $error');
    }

    if (stackTrace != null) {
      buffer.writeln('');
      buffer.writeln('Dart stack (first 8 lines):');
      buffer.writeln(
        stackTrace
            .toString()
            .split('\n')
            .take(8)
            .join('\n'),
      );
    }

    return buffer.toString().trimRight();
  }

  static String? hintForPlatformException(PlatformException error) {
    final combined =
        '${error.code} ${error.message ?? ''} ${_stringify(error.details)}';

    if (_isDeveloperError(combined)) {
      return _developerErrorHint();
    }

    if (error.code == 'sign_in_canceled' ||
        combined.toLowerCase().contains('cancel')) {
      return 'User cancelled the Google account picker.';
    }

    if (error.code == 'network_error' ||
        combined.toLowerCase().contains('network')) {
      return 'Network issue while contacting Google. Check internet connection.';
    }

    return null;
  }

  static bool _isDeveloperError(String combined) {
    final lower = combined.toLowerCase();
    return lower.contains('sign_in_failed') &&
        (RegExp(r'\b10\b').hasMatch(combined) ||
            lower.contains('developer_error') ||
            lower.contains('apiexception: 10'));
  }

  static String _developerErrorHint() {
    final webId = GoogleConfig.webClientId;
    final webIdStatus = webId.isEmpty
        ? 'MISSING — APK was built without GOOGLE_WEB_CLIENT_ID'
        : 'set (${maskClientId(webId)})';

    return 'DEVELOPER_ERROR (Android code 10)\n'
        'Google rejected this app\'s OAuth registration. Common causes:\n'
        '• Installed APK SHA-1 does not match Google Cloud Android client\n'
        '• Package name on device is not com.spendwise.mobile\n'
        '• Web client ID missing or wrong type (must be Web application)\n'
        '• Gmail is not listed under OAuth consent screen → Test users\n\n'
        'Built-in Web client ID: $webIdStatus';
  }

  static String clientIdKey(String clientId) {
    if (clientId.isEmpty) return '(empty)';
    final dash = clientId.indexOf('-');
    if (dash < 0) return clientId;
    final dot = clientId.indexOf('.apps.googleusercontent.com');
    if (dot <= dash) return clientId.substring(dash + 1);
    return clientId.substring(dash + 1, dot);
  }

  static Future<String> buildConfigReport() async {
    final info = await PackageInfo.fromPlatform();
    final webId = GoogleConfig.webClientId;
    final webKey = clientIdKey(webId);

    return '''
=== OAuth debug info ===
Installed package: ${info.packageName}
Expected package: ${GoogleConfig.androidPackageName}
Package match: ${info.packageName == GoogleConfig.androidPackageName ? 'yes' : 'NO — mismatch'}
App version: ${info.version}+${info.buildNumber}

Web client ID in APK: ${webId.isEmpty ? 'NOT SET' : maskClientId(webId)}
Web client ID key: ${webKey.isEmpty ? '(empty)' : webKey}
Web client ID length: ${webId.length} chars
Web client ID ends with .apps.googleusercontent.com: ${webId.endsWith('.apps.googleusercontent.com')}

Verify Web client key starts with: 8m1kv (SpendWise Web)
If it starts with tluho, APK is still using the old Desktop client ID.

Scopes requested:
${GoogleSignInDebugReport.scopes.map((s) => '• $s').join('\n')}

If error 10 persists with package match + Web key 8m1kv…:
→ SHA-1 mismatch. Compare Build APK log "Print APK signing SHA-1"
  with Google Cloud → SpendWise Android → SHA-1 fingerprint.

Google Cloud checks:
• Android OAuth client package = com.spendwise.mobile
• Android OAuth client SHA-1 = must match Print APK signing SHA-1 exactly
• Web OAuth client = SpendWise Web (not Android client ID)
• Test user = same Gmail you select when signing in
'''.trim();
  }

  static const scopes = _scopes;

  static String maskClientId(String clientId) {
    if (clientId.isEmpty) return '(empty)';

    const suffix = '.apps.googleusercontent.com';
    if (clientId.endsWith(suffix) && clientId.length > suffix.length + 8) {
      final dash = clientId.indexOf('-');
      final prefixEnd = dash > 0 ? dash : 12;
      return '${clientId.substring(0, prefixEnd)}…$suffix';
    }

    if (clientId.length <= 20) {
      return '${clientId.substring(0, 4)}…${clientId.substring(clientId.length - 4)}';
    }
    return '${clientId.substring(0, 12)}…${clientId.substring(clientId.length - 12)}';
  }

  static String _stringify(Object? value) {
    if (value == null) return '(null)';
    return value.toString();
  }
}

/// Visible for tests — mirrors scopes used by [GoogleAuthService].
const _scopes = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive.file',
];
