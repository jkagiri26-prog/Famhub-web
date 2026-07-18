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

    // Get access token from Supabase session
    final session = _supabase.currentSession;
    final token = session?.accessToken;

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
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
      final response = await _client
          .get(
            _buildUri(
              endpoint,
              queryParameters: queryParameters,
            ),
            headers: await _headers(),
          )
          .timeout(_timeout);

      return _processResponse(response);
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
      final response = await _client
          .post(
            _buildUri(
              endpoint,
              queryParameters: queryParameters,
            ),
            headers: await _headers(),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeout);

      return _processResponse(response);
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
      final response = await _client
          .put(
            _buildUri(endpoint),
            headers: await _headers(),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_timeout);

      return _processResponse(response);
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
      final response = await _client
          .delete(
            _buildUri(endpoint),
            headers: await _headers(),
          )
          .timeout(_timeout);

      return _processResponse(response);
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