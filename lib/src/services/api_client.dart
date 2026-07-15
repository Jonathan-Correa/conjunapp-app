import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);

/// Cliente HTTP autenticado contra la API ConjunApp.
class ApiClient {
  final AuthService? _authService;

  ApiClient({AuthService? authService}) : _authService = authService;

  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl$path'),
      headers: await _getHeaders(),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getList(String path) async {
    final data = await get(path);
    if (data == null) return [];
    return List<dynamic>.from(data as List);
  }

  Future<dynamic> post(String path, {required Map<String, dynamic> body}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final response = await http.patch(
      Uri.parse('$apiBaseUrl$path'),
      headers: await _getHeaders(),
      body: body == null ? null : jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {required Map<String, dynamic> body}) async {
    final response = await http.put(
      Uri.parse('$apiBaseUrl$path'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl$path'),
      headers: await _getHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await _authService?.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw ApiException('Error al decodificar respuesta: $e');
      }
    }

    String? detail;
    try {
      final error = jsonDecode(response.body);
      if (error is Map<String, dynamic>) {
        final raw = error['detail'];
        if (raw is String) {
          detail = raw;
        } else if (raw != null) {
          detail = raw.toString();
        }
      }
    } catch (_) {}

    if (response.statusCode == 401) {
      throw ApiException(detail ?? 'No autorizado. Inicia sesión de nuevo.');
    }
    if (response.statusCode == 403) {
      throw ApiException(detail ?? 'Acceso denegado.');
    }
    if (response.statusCode == 404) {
      throw ApiException(detail ?? 'Recurso no encontrado.');
    }
    if (response.statusCode >= 500) {
      throw ApiException(detail ?? 'Error del servidor. Intenta más tarde.');
    }
    throw ApiException(detail ?? 'Error en la solicitud (${response.statusCode})');
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
