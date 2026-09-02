import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/integrations/google_sign_in_debug.dart';

void main() {
  group('GoogleSignInDebugReport', () {
    test('formatError includes PlatformException fields', () {
      final error = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: ',
        details: {'statusCode': 10},
      );

      final text = GoogleSignInDebugReport.formatError(error);

      expect(text, contains('Code: sign_in_failed'));
      expect(text, contains('Message: com.google.android.gms.common.api.ApiException: 10:'));
      expect(text, contains('Details:'));
      expect(text, contains('DEVELOPER_ERROR'));
    });

    test('hintForPlatformException detects error 10', () {
      final error = PlatformException(
        code: 'sign_in_failed',
        message: 'd1: 10: ',
      );

      final hint = GoogleSignInDebugReport.hintForPlatformException(error);

      expect(hint, isNotNull);
      expect(hint, contains('DEVELOPER_ERROR'));
    });

    test('clientIdKey extracts unique segment after dash', () {
      const id =
          '1020454676892-8m1kv1d23mmsme16909b38av1mek6ghd.apps.googleusercontent.com';

      expect(
        GoogleSignInDebugReport.clientIdKey(id),
        '8m1kv1d23mmsme16909b38av1mek6ghd',
      );
    });

    test('maskClientId hides middle of long client id', () {
      const id =
          '1020454676892-tluhoep2nvtr78jhqvhv1s9rjo7em34g.apps.googleusercontent.com';

      final masked = GoogleSignInDebugReport.maskClientId(id);

      expect(masked, startsWith('1020454676892'));
      expect(masked, endsWith('.apps.googleusercontent.com'));
      expect(masked, contains('…'));
    });
  });
}
