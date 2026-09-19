import 'dart:async';
import 'dart:convert';

// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';

class ApiService {
  ApiService({
    SupabaseService? supabase,
    http.Client? client,
    this.baseUrl = _defaultBaseUrl,
  }) : _client = client ?? http.Client(),
       _supabase = supabase ?? SupabaseService.instance;

  static const String _defaultBaseUrl = 'https://api.famhub.com';

  final SupabaseService _supabase;
  final http.Client _client;
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 30);

  /// =========================
  /// HEADERS
  /// =========================

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Always use the current Supabase session access token. Never the anon
    // key, never a manually constructed JWT.
    final token = _supabase.accessToken;

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Sends an authenticated request and retries ONCE after refreshing the
  /// session when the server answers 401/403 with a stale/invalid token.
  Future<dynamic> _execute(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var response = await send(await _headers());

    // Only a 401 means the access token is missing/stale. A 403 is a
    // legitimate authorization denial and must NOT trigger a token refresh.
    if (response.statusCode == 401) {
      final refreshed = await _supabase.refreshSessionSafely();
      if (refreshed) {
        response = await send(await _headers());
      }
    }

    return _processResponse(response);
  }

  /// =========================
  /// URI BUILDER
  /// =========================

  Uri _buildUri(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) {
    final sanitizedEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;

    return Uri.parse(
      '$baseUrl/$sanitizedEndpoint',
    ).replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  /// =========================
  /// GET
  /// =========================

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _execute(
        (headers) => _client
            .get(
              _buildUri(
                endpoint,
                queryParameters: queryParameters,
              ),
              headers: headers,
            )
            .timeout(_timeout),
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 408,
      );
    } catch (e) {
      throw ApiException(
        message: 'GET request failed: $e',
      );
    }
  }

  /// =========================
  /// POST
  /// =========================

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _execute(
        (headers) => _client
            .post(
              _buildUri(
                endpoint,
                queryParameters: queryParameters,
              ),
              headers: headers,
              body: jsonEncode(body ?? {}),
            )
            .timeout(_timeout),
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 408,
      );
    } catch (e) {
      throw ApiException(
        message: 'POST request failed: $e',
      );
    }
  }

  /// =========================
  /// PUT
  /// =========================

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      return await _execute(
        (headers) => _client
            .put(
              _buildUri(endpoint),
              headers: headers,
              body: jsonEncode(body ?? {}),
            )
            .timeout(_timeout),
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 408,
      );
    } catch (e) {
      throw ApiException(
        message: 'PUT request failed: $e',
      );
    }
  }

  /// =========================
  /// DELETE
  /// =========================

  Future<dynamic> delete(
    String endpoint,
  ) async {
    try {
      return await _execute(
        (headers) => _client
            .delete(
              _buildUri(endpoint),
              headers: headers,
            )
            .timeout(_timeout),
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Request timeout',
        statusCode: 408,
      );
    } catch (e) {
      throw ApiException(
        message: 'DELETE request failed: $e',
      );
    }
  }

  /// =========================
  /// RESPONSE PROCESSOR
  /// =========================

  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    dynamic data;

    try {
      data = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;
    } catch (_) {
      data = response.body;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return data;
    }

    throw ApiException(
      message: data is Map<String, dynamic>
          ? (data['message']?.toString() ??
              'Unknown server error')
          : 'Server error',
      statusCode: statusCode,
      response: data,
    );
  }

  void dispose() {
    _client.close();
  }
}

/// =========================
/// API EXCEPTION
/// =========================

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.response,
  });

  final String message;
  final int? statusCode;
  final dynamic response;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message)';
  }
}