import '../models/user.dart';
import '../utils/constants.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<bool> register(String email, String password) async {
    try {
      final response = await _api.post(
        AppConstants.registerEndpoint,
        {'email': email, 'password': password},
      );
      return response['message'] == 'User registered successfully';
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  Future<User> login(String email, String password) async {
    try {
      final response = await _api.post(
        AppConstants.loginEndpoint,
        {'email': email, 'password': password},
      );

      await _storage.saveToken(response['access_token']);
      await _storage.saveRefreshToken(response['refresh_token']);
      await _storage.saveUserEmail(email);

      return User(userId: 0, email: email);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Exchange the stored refresh token for new tokens.
  /// Returns true on success, false if the refresh token is missing/expired
  /// (caller should force logout).
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _api.post(
        AppConstants.refreshEndpoint,
        {'refresh_token': refreshToken},
      );

      await _storage.saveToken(response['access_token']);
      await _storage.saveRefreshToken(response['refresh_token']);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null;
  }

  StorageService get storage => _storage;
}
