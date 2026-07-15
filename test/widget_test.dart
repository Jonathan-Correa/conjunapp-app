import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conjunapp_resident/main.dart';
import 'package:conjunapp_resident/src/services/auth_service.dart';
import 'package:conjunapp_resident/src/services/api_client.dart';
import 'package:conjunapp_resident/src/providers/auth_provider.dart';

void main() {
  testWidgets('App carga pantalla de autenticación', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => AuthService()),
          ProxyProvider<AuthService, ApiClient>(
            update: (_, auth, __) => ApiClient(authService: auth),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('ConjunApp'), findsWidgets);
  });
}
