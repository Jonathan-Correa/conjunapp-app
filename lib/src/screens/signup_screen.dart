import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: '');
  final _fullNameController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '');
  final _documentController = TextEditingController(text: '');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedTower;
  String? _selectedUnit;
  String _residentType = 'owner';
  bool _isOwner = true;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _towers = [];
  Map<String, List<Map<String, dynamic>>> _unitsByTower = {};

  @override
  void initState() {
    super.initState();
    _loadTowers();
  }

  Future<void> _loadTowers() async {
    try {
      final client = ApiClient();
      final response = await client.get('/towers');

      setState(() {
        _towers = List<Map<String, dynamic>>.from(response);
        for (var tower in _towers) {
          _unitsByTower[tower['name']] =
              List<Map<String, dynamic>>.from(tower['units'] ?? []);
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar torres: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTower == null || _selectedUnit == null) {
      setState(() => _error = 'Por favor selecciona torre y unidad');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      // First, create the resident account via API
      final payload = {
        'email': _emailController.text,
        'full_name': _fullNameController.text,
        'password': _passwordController.text,
        'password_confirm': _confirmPasswordController.text,
        'phone': _phoneController.text,
        'document_number': _documentController.text,
        'resident_type': _residentType,
        'is_owner': _isOwner,
        'tower_name': _selectedTower,
        'unit_number': _selectedUnit,
      };

      final client = ApiClient();
      final response = await client.post('/auth/resident/register', body: payload);

      // Now login with the response
      await authProvider.login(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Registro exitoso!')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _documentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrarse'),
        elevation: 0,
        backgroundColor: const Color(0xFF176b5c),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'Crear Cuenta Residente',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF176b5c),
                      ),
                ),
                const SizedBox(height: 24),

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabled: !_isLoading,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Requerido';
                    if (!value!.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Full name field
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabled: !_isLoading,
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // Phone field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabled: !_isLoading,
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // Document field
                TextFormField(
                  controller: _documentController,
                  decoration: InputDecoration(
                    labelText: 'Número de documento',
                    prefixIcon: const Icon(Icons.assignment),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabled: !_isLoading,
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // Tower selection
                DropdownButtonFormField<String>(
                  value: _selectedTower,
                  decoration: InputDecoration(
                    labelText: 'Torre',
                    prefixIcon: const Icon(Icons.apartment),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _towers.map((tower) {
                    return DropdownMenuItem<String>(
                      value: tower['name'] as String,
                      child: Text(tower['name'] as String),
                    );
                  }).toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _selectedTower = value;
                            _selectedUnit = null;
                          });
                        },
                  validator: (value) =>
                      (value == null) ? 'Selecciona una torre' : null,
                ),
                const SizedBox(height: 16),

                // Unit selection
                if (_selectedTower != null)
                  DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: 'Unidad',
                      prefixIcon: const Icon(Icons.meeting_room),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: (_unitsByTower[_selectedTower] ?? []).map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit['number'] as String,
                        child: Text(unit['number'] as String),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() => _selectedUnit = value);
                          },
                    validator: (value) =>
                        (value == null) ? 'Selecciona una unidad' : null,
                  ),
                const SizedBox(height: 16),

                // Resident type selection
                DropdownButtonFormField<String>(
                  value: _residentType,
                  decoration: InputDecoration(
                    labelText: 'Tipo de residente',
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'owner',
                      child: Text('Propietario'),
                    ),
                    DropdownMenuItem(
                      value: 'tenant',
                      child: Text('Inquilino'),
                    ),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _residentType = value ?? 'owner';
                            _isOwner = value == 'owner';
                          });
                        },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabled: !_isLoading,
                  ),
                  obscureText: !_showPassword,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Requerido';
                    if ((value?.length ?? 0) < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(
                          () => _showConfirmPassword = !_showConfirmPassword,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabled: !_isLoading,
                  ),
                  obscureText: !_showConfirmPassword,
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Requerido' : null,
                ),
                const SizedBox(height: 24),

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF176b5c),
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Registrarse',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿Ya tienes cuenta? '),
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Inicia sesión aquí',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF176b5c),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
