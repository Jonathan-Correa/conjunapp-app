import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/services/auth_service.dart';
import 'src/services/api_client.dart';
import 'src/services/resident_api.dart';
import 'src/providers/auth_provider.dart';
import 'src/models/auth.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        ProxyProvider<AuthService, ApiClient>(
          update: (_, auth, __) => ApiClient(authService: auth),
        ),
        ProxyProvider<ApiClient, ResidentApi>(
          update: (_, client, __) => ResidentApi(client),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
          ),
        ),
      ],
      child: const ConjunAppResident(),
    ),
  );
}

class ConjunAppResident extends StatelessWidget {
  const ConjunAppResident({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConjunApp Residentes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b5c)),
        scaffoldBackgroundColor: const Color(0xfff4f7f2),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff176b5c),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const _RootNavigator(),
    );
  }
}

class _RootNavigator extends StatelessWidget {
  const _RootNavigator();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading && authProvider.state == AuthState.loading) {
          return const _LoadingScreen();
        }
        return authProvider.isAuthenticated
            ? const HomeScreen()
            : const LoginScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7f2),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff176b5c)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ConjunApp',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xff176b5c),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cargando aplicación...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
