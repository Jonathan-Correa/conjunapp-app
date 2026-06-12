import 'package:flutter/foundation.dart';
import '../models/auth.dart';
import '../services/auth_service.dart';

/// Provider para manejar el estado de autenticación
class AuthProvider with ChangeNotifier {
  final AuthService _authService;

  ResidentUser? _user;
  String? _token;
  AuthState _state = AuthState.loading;
  String? _errorMessage;

  AuthProvider({required AuthService authService})
      : _authService = authService {
    _initializeAuth();
  }

  // Getters
  ResidentUser? get user => _user;
  String? get token => _token;
  AuthState get state => _state;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get hasError => _state == AuthState.error;

  /// Inicializar autenticación (verificar sesión existente)
  Future<void> _initializeAuth() async {
    try {
      _state = AuthState.loading;
      notifyListeners();

      // Intentar cargar usuario en caché
      _user = await _authService.getCachedUser();
      _token = await _authService.getToken();

      if (_token != null && _user != null) {
        // Verificar que el token siga siendo válido
        try {
          final currentUser = await _authService.getCurrentUser();
          _user = currentUser;
          _state = AuthState.authenticated;
        } catch (e) {
          // Token expirado, limpiar sesión
          await logout();
          _state = AuthState.unauthenticated;
        }
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Hacer login con correo y contraseña
  Future<bool> login(String email, String password) async {
    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      final response = await _authService.login(email, password);
      _user = response.user;
      _token = response.accessToken;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _state = AuthState.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Error inesperado: $e';
      notifyListeners();
      return false;
    }
  }

  /// Hacer logout
  Future<void> logout() async {
    try {
      await _authService.logout();
      _user = null;
      _token = null;
      _state = AuthState.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cerrar sesión: $e';
      notifyListeners();
    }
  }

  /// Limpiar mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
