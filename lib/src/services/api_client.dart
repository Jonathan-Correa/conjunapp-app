import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);

/// Cliente HTTP para hacer peticiones a la API del backend
class ApiClient {
  final AuthService? _authService;

  ApiClient({AuthService? authService}) : _authService = authService;

  /// Hacer una petición GET
  Future<dynamic> get(String path) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = await _getHeaders();

    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  /// Hacer una petición POST
  Future<dynamic> post(String path,
      {required Map<String, dynamic> body}) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = await _getHeaders();

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  /// Hacer una petición PUT
  Future<dynamic> put(String path, {required Map<String, dynamic> body}) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = await _getHeaders();

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  /// Hacer una petición DELETE
  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = await _getHeaders();

    final response = await http.delete(uri, headers: headers);
    return _handleResponse(response);
  }

  /// Obtener headers con token de autenticación
  Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await _authService?.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Manejar la respuesta del servidor
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw ApiException('Error al decodificar respuesta: $e');
      }
    } else if (response.statusCode == 401) {
      throw ApiException('No autorizado. Por favor, inicie sesión de nuevo.');
    } else if (response.statusCode == 403) {
      throw ApiException('Acceso denegado.');
    } else if (response.statusCode == 404) {
      throw ApiException('Recurso no encontrado.');
    } else if (response.statusCode >= 500) {
      throw ApiException('Error del servidor. Por favor, intente más tarde.');
    } else {
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = error['detail'] as String?;
        throw ApiException(detail ?? 'Error en la solicitud');
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException('Error en la solicitud: ${response.statusCode}');
      }
    }
  }
}

/// Excepción personalizada para errores de API
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
