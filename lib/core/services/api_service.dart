import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = "https://api.famhub.com";

  /// Centralized headers, automatically including Auth tokens if logged in
  static Map<String, String> _getHeaders() {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (AuthService.isLoggedIn()) {
      headers['Authorization'] = 'Bearer ${AuthService.getUserId()}';
    }
    
    return headers;
  }

  static Future<T> get<T>(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$endpoint"),
        headers: _getHeaders(),
      );
      return _processResponse<T>(response);
    } catch (e) {
      throw Exception("FAMHUB_API_ERROR: GET $endpoint failed -> $e");
    }
  }

  static Future<T> post<T>(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/$endpoint"),
        headers: _getHeaders(),
        body: jsonEncode(data),
      );
      return _processResponse<T>(response);
    } catch (e) {
      throw Exception("FAMHUB_API_ERROR: POST $endpoint failed -> $e");
    }
  }

  /// Internal response processor to handle status codes and decoding
  static T _processResponse<T>(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as T;
    } else {
      throw Exception("Server Error: ${response.statusCode} - ${response.body}");
    }
  }
}