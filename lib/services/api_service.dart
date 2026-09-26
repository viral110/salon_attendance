import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_endpoints.dart';
import '../utils/api_logger.dart';

/// Common API service for executing HTTP requests across the application.
class ApiService {
  final String baseUrl;
  final http.Client _client;

  static final ApiService _instance = ApiService._internal();

  factory ApiService({String? baseUrl, http.Client? client}) {
    if (baseUrl == null && client == null) {
      return _instance;
    }
    return ApiService._internal(baseUrl: baseUrl, client: client);
  }

  ApiService._internal({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiEndpoints.baseUrl,
        _client = client ?? http.Client();

  /// Default headers builder
  Map<String, String> _buildHeaders({
    Map<String, String>? customHeaders,
    bool isJson = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  /// Builds a Uri object given an endpoint (relative path or full URL) and optional query parameters
  Uri buildUri(String endpoint, [Map<String, String>? queryParameters]) {
    String fullUrl;
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      fullUrl = endpoint;
    } else {
      final String cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      fullUrl = '$baseUrl$cleanEndpoint';
    }

    final Uri baseUri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final Map<String, String> filteredQuery = {};
      queryParameters.forEach((key, value) {
        if (value.isNotEmpty) {
          filteredQuery[key] = value;
        }
      });
      return baseUri.replace(queryParameters: {
        ...baseUri.queryParameters,
        ...filteredQuery,
      });
    }
    return baseUri;
  }

  /// Executes an HTTP GET request with central logging and header construction.
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = buildUri(endpoint, queryParameters);
    final requestHeaders = _buildHeaders(customHeaders: headers);
    final urlStr = uri.toString();

    ApiLogger.logRequest(method: 'GET', url: urlStr, headers: requestHeaders);

    try {
      final response = await _client.get(
        uri,
        headers: requestHeaders,
      );

      ApiLogger.logResponse(
        method: 'GET',
        url: urlStr,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      return response;
    } catch (e) {
      ApiLogger.logError(method: 'GET', url: urlStr, error: e);
      rethrow;
    }
  }

  /// Executes an HTTP POST request with central logging, header construction, and JSON serialization.
  Future<http.Response> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
    bool isJson = true,
  }) async {
    final uri = buildUri(endpoint);
    final requestHeaders = _buildHeaders(customHeaders: headers, isJson: isJson);
    final urlStr = uri.toString();

    final dynamic bodyPayload = (isJson && body != null && body is! String)
        ? jsonEncode(body)
        : body;

    ApiLogger.logRequest(
      method: 'POST',
      url: urlStr,
      headers: requestHeaders,
      body: bodyPayload,
    );

    try {
      final response = await _client.post(
        uri,
        headers: requestHeaders,
        body: bodyPayload,
      );

      ApiLogger.logResponse(
        method: 'POST',
        url: urlStr,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      return response;
    } catch (e) {
      ApiLogger.logError(method: 'POST', url: urlStr, error: e);
      rethrow;
    }
  }
}
