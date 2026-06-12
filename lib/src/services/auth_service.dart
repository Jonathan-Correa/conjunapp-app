import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/auth.dart';

const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);

/// Servicio de autenticación que maneja login, logout y persistencia de tokens
class AuthService {
  static const String _tokenKey = 'access_token';
  static const String _userKey = 'auth_user';
  static const String _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Hacer login con correo y contraseña
  Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/auth/resident/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      // Guardar token y usuario en almacenamiento seguro
      await _storage.write(key: _tokenKey, value: authResponse.accessToken);
      await _storage.write(
          key: _userKey, value: jsonEncode(authResponse.user.toJson()));

      return authResponse;
    } else if (response.statusCode == 401) {
      throw AuthException('Credenciales de residente inválidas');
    } else {
      final error = _parseErrorResponse(response);
      throw AuthException(error ?? 'Error al iniciar sesión');
    }
  }

  /// Obtener usuario actual desde el servidor
  Future<ResidentUser> getCurrentUser() async {
    final token = await getToken();
    if (token == null) {
      throw AuthException('No hay sesión activa');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/auth/resident/me'),
      headers: _getAuthHeaders(token),
    );

    if (response.statusCode == 200) {
      return ResidentUser.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else if (response.statusCode == 401) {
      // Token expirado o inválido
      await logout();
      throw AuthException('Sesión expirada');
    } else {
      final error = _parseErrorResponse(response);
      throw AuthException(error ?? 'Error al obtener usuario');
    }
  }

  /// Obtener el token de acceso actual
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Obtener el usuario autenticado desde almacenamiento local
  Future<ResidentUser?> getCachedUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson == null) return null;
    try {
      return ResidentUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Verificar si hay una sesión activa
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Cerrar sesión y limpiar datos
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Obtener headers de autenticación con el token
  Map<String, String> _getAuthHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Parsear mensaje de error de la respuesta
  static String? _parseErrorResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['detail'] as String?;
    } catch (_) {
      return response.reasonPhrase;
    }
  }
}

/// Excepción personalizada para errores de autenticación
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
