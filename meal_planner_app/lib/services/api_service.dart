import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final StorageService _storage = StorageService();

  Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (includeAuth) {
      final token = await _storage.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  /// Attempts to use the stored refresh token to get new tokens.
  /// Returns true on success. On failure, clears all storage.
  Future<bool> _tryRefresh() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      final url = Uri.parse('${AppConstants.baseUrl}${AppConstants.refreshEndpoint}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.saveToken(data['access_token']);
        await _storage.saveRefreshToken(data['refresh_token']);
        return true;
      }
    } catch (_) {}
    await _storage.clearAll();
    return false;
  }

  // ── Request helpers ───────────────────────────────────────────────────────

  String _extractDetail(Map<String, dynamic> error) {
    final detail = error['detail'];
    if (detail == null) return 'Request failed';
    if (detail is String) return detail;
    if (detail is List) {
      // Pydantic 422 validation errors — extract just the human-readable msg
      final messages = detail
          .whereType<Map>()
          .map((e) => e['msg']?.toString())
          .where((m) => m != null && m.isNotEmpty)
          .toList();
      if (messages.isNotEmpty) return messages.join('. ');
    }
    return detail.toString();
  }

  Exception _handleError(int statusCode, Map<String, dynamic> error) {
    final message = _extractDetail(error);
    if (statusCode == 401) {
      return TokenExpiredException(message);
    }
    return Exception(message);
  }

  /// Runs [request]. If it returns 401 and auth was included, tries to refresh
  /// once then retries. Throws [TokenExpiredException] if refresh fails.
  Future<http.Response> _withAutoRefresh({
    required bool includeAuth,
    required Future<http.Response> Function(Map<String, String> headers) request,
  }) async {
    var headers = await _getHeaders(includeAuth: includeAuth);
    var response = await request(headers);

    if (response.statusCode == 401 && includeAuth) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        final error = jsonDecode(response.body);
        throw TokenExpiredException(error['detail'] ?? 'Session expired. Please login again.');
      }
      headers = await _getHeaders(includeAuth: true);
      response = await request(headers);
    }

    return response;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final response = await _withAutoRefresh(
      includeAuth: includeAuth,
      request: (h) => http.post(url, headers: h, body: jsonEncode(body)),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw _handleError(response.statusCode, jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool includeAuth = false,
    Map<String, String>? queryParams,
  }) async {
    var url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }
    final response = await _withAutoRefresh(
      includeAuth: includeAuth,
      request: (h) => http.get(url, headers: h),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw _handleError(response.statusCode, jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final response = await _withAutoRefresh(
      includeAuth: includeAuth,
      request: (h) => http.put(url, headers: h, body: jsonEncode(body)),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw _handleError(response.statusCode, jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool includeAuth = false,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final response = await _withAutoRefresh(
      includeAuth: includeAuth,
      request: (h) => http.delete(url, headers: h),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw _handleError(response.statusCode, jsonDecode(response.body));
  }

  /// GET that returns a List (for endpoints returning JSON arrays)
  Future<List<dynamic>> getList(
    String endpoint, {
    bool includeAuth = false,
    Map<String, String>? queryParams,
  }) async {
    var url = Uri.parse('${AppConstants.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }
    final response = await _withAutoRefresh(
      includeAuth: includeAuth,
      request: (h) => http.get(url, headers: h),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw _handleError(response.statusCode, jsonDecode(response.body));
  }
}

// Custom exception for token expiry
class TokenExpiredException implements Exception {
  final String message;
  TokenExpiredException(this.message);

  @override
  String toString() => message;
}
