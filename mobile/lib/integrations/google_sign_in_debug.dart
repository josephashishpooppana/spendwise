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

  static Future<String> buildConfigReport() async {
    final info = await PackageInfo.fromPlatform();
    final webId = GoogleConfig.webClientId;

    return '''
=== OAuth debug info ===
Installed package: ${info.packageName}
Expected package: ${GoogleConfig.androidPackageName}
Package match: ${info.packageName == GoogleConfig.androidPackageName ? 'yes' : 'NO — mismatch'}
App version: ${info.version}+${info.buildNumber}

Web client ID in APK: ${webId.isEmpty ? 'NOT SET' : maskClientId(webId)}
Web client ID length: ${webId.length} chars
Web client ID ends with .apps.googleusercontent.com: ${webId.endsWith('.apps.googleusercontent.com')}

Scopes requested:
${GoogleSignInDebugReport.scopes.map((s) => '• $s').join('\n')}

Google Cloud checks:
• Android OAuth client package = com.spendwise.mobile
• Android OAuth client SHA-1 = Print APK signing SHA-1 from Build APK workflow
• Web OAuth client type = Web application (not Desktop/Installed)
• Test user = same Gmail you select when signing in
'''.trim();
  }

  static const scopes = _scopes;

  static String maskClientId(String clientId) {
    if (clientId.isEmpty) return '(empty)';
    if (clientId.length <= 20) {
      return '${clientId.substring(0, 4)}…${clientId.substring(clientId.length - 4)}';
    }
    return '${clientId.substring(0, 12)}…${clientId.substring(clientId.length - 20)}';
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
