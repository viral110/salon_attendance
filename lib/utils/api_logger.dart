import 'package:flutter/foundation.dart';

class ApiLogger {
  static void logRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
  }) {
    debugPrint('==================================================');
    debugPrint('🌐 [API REQUEST] $method $url');
    if (headers != null && headers.isNotEmpty) {
      debugPrint('   Headers: $headers');
    }
    if (body != null) {
      debugPrint('   Body: $body');
    }
    debugPrint('==================================================');
  }

  static void logResponse({
    required String method,
    required String url,
    required int statusCode,
    required String responseBody,
  }) {
    final statusSymbol = (statusCode >= 200 && statusCode < 300) ? '✅' : '❌';
    debugPrint('==================================================');
    debugPrint('$statusSymbol [API RESPONSE] [$statusCode] $method $url');
    debugPrint('   Payload: ${responseBody.length > 500 ? "${responseBody.substring(0, 500)}..." : responseBody}');
    debugPrint('==================================================');
  }

  static void logError({
    required String method,
    required String url,
    required dynamic error,
  }) {
    debugPrint('==================================================');
    debugPrint('🚨 [API ERROR] $method $url');
    debugPrint('   Error Details: $error');
    debugPrint('==================================================');
  }
}
