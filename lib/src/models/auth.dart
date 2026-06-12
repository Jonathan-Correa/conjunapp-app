/// Modelos de autenticación para la app de residentes

/// Datos del usuario residente autenticado
class ResidentUser {
  final String id;
  final String email;
  final String fullName;
  final String residentId;
  final String unitId;
  final String unit;
  final String phone;
  final String documentNumber;

  ResidentUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.residentId,
    required this.unitId,
    required this.unit,
    required this.phone,
    required this.documentNumber,
  });

  /// Crear desde JSON de la API
  factory ResidentUser.fromJson(Map<String, dynamic> json) {
    return ResidentUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      residentId: json['resident_id'] as String,
      unitId: json['unit_id'] as String,
      unit: json['unit'] as String,
      phone: json['phone'] as String,
      documentNumber: json['document_number'] as String,
    );
  }

  /// Convertir a JSON para almacenamiento
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'resident_id': residentId,
        'unit_id': unitId,
        'unit': unit,
        'phone': phone,
        'document_number': documentNumber,
      };
}

/// Respuesta de autenticación del servidor
class AuthResponse {
  final String accessToken;
  final String tokenType;
  final ResidentUser user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  /// Crear desde JSON de la API
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      user: ResidentUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Convertir a JSON para almacenamiento
  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'user': user.toJson(),
      };
}

/// Credenciales de login
class LoginCredentials {
  final String email;
  final String password;

  LoginCredentials({
    required this.email,
    required this.password,
  });

  /// Convertir a JSON para enviar al servidor
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

/// Estados de autenticación
enum AuthState {
  unauthenticated,
  authenticated,
  loading,
  error,
}
