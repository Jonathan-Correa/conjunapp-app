import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'src/services/auth_service.dart';
import 'src/providers/auth_provider.dart';
import 'src/models/auth.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // AuthService es un singleton
        Provider(create: (_) => AuthService()),
        // AuthProvider depende de AuthService
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

// Minimal API client stub to allow the UI to compile
class ApiClient {
  Future<List<dynamic>> getList(String path) async {
    // Return empty lists by default; replace with real API calls.
    return <dynamic>[];
  }

  Future<void> post(String path, Map<String, dynamic> body) async {
    // No-op; replace with real API calls.
    return;
  }
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
      ),
      home: _RootNavigator(),
      navigatorObservers: [_RouteLogger()],
    );
  }
}

/// Widget que maneja la navegación según el estado de autenticación
class _RootNavigator extends StatelessWidget {
  const _RootNavigator();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Mostrar pantalla de loading mientras se inicializa la autenticación
        if (authProvider.isLoading && authProvider.state == AuthState.loading) {
          return const _LoadingScreen();
        }

        // Navegar a login o home según el estado de autenticación
        return authProvider.isAuthenticated
            ? const HomeScreen()
            : const LoginScreen();
      },
    );
  }
}

/// Pantalla de loading durante la inicialización
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xff176b5c),
                ),
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

/// Observer para registrar cambios de ruta (útil para debugging)
class _RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navegó a: ${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Regresó de: ${route.settings.name}');
  }
}

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  final api = ApiClient();
  final currency =
      NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 0);
  bool loading = true;
  int tabIndex = 0;
  String message = '';
  Map<String, dynamic>? resident;
  List<dynamic> residents = [];
  List<dynamic> invoices = [];
  List<dynamic> areas = [];
  List<dynamic> reservations = [];
  List<dynamic> visitors = [];
  List<dynamic> announcements = [];

  String get residentId => resident?['id']?.toString() ?? '';
  String get unitLabel => resident?['unit']?.toString() ?? 'Unidad';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      residents = await api.getList('/admin/residents');
      resident =
          residents.isNotEmpty ? residents.first as Map<String, dynamic> : null;
      await loadResidentData();
    } catch (error) {
      message = error.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadResidentData() async {
    areas = await api.getList('/common-areas');
    reservations = residentId.isEmpty
        ? []
        : await api.getList('/reservations?resident_id=$residentId');
    visitors = residentId.isEmpty
        ? []
        : await api.getList('/visitors?resident_id=$residentId');
    announcements = await api.getList('/announcements');
    invoices = await api.getList('/invoices?only_open=true');
  }

  Future<void> refreshWithMessage(String nextMessage) async {
    await loadResidentData();
    setState(() => message = nextMessage);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      AccountPage(invoices: invoices, currency: currency, onPay: payInvoice),
      ReservationsPage(
          areas: areas,
          reservations: reservations,
          currency: currency,
          onCreate: createReservation),
      VisitorsPage(visitors: visitors, onCreate: createVisitor),
      AnnouncementsPage(announcements: announcements),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ConjunApp'),
            Text(unitLabel, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar'),
        ],
      ),
      body: Column(
        children: [
          if (message.isNotEmpty)
            MaterialBanner(
              content: Text(message),
              leading: const Icon(Icons.info_outline),
              actions: [
                TextButton(
                    onPressed: () => setState(() => message = ''),
                    child: const Text('OK'))
              ],
            ),
          Expanded(child: pages[tabIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (index) => setState(() => tabIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.receipt_long), label: 'Cuenta'),
          NavigationDestination(
              icon: Icon(Icons.event_available), label: 'Reservas'),
          NavigationDestination(
              icon: Icon(Icons.qr_code_2), label: 'Visitantes'),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'Avisos'),
        ],
      ),
    );
  }

  Future<void> payInvoice(Map<String, dynamic> invoice) async {
    await api.post('/payments', {
      'invoice_id': invoice['id'],
      'amount': invoice['total'],
      'method': 'PSE',
      'gateway_reference': 'APP-${DateTime.now().millisecondsSinceEpoch}',
    });
    await refreshWithMessage('Pago registrado correctamente.');
  }

  Future<void> createReservation(
      String areaId, DateTime startsAt, int hours) async {
    final endsAt = startsAt.add(Duration(hours: hours));
    await api.post('/reservations', {
      'resident_id': residentId,
      'common_area_id': areaId,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
    });
    await refreshWithMessage(
        'Reserva enviada. Si el horario esta ocupado quedara en lista de espera.');
  }

  Future<void> createVisitor(
      String name, String? document, String? plate) async {
    final now = DateTime.now();
    await api.post('/visitors', {
      'resident_id': residentId,
      'visitor_name': name,
      'document_number': document,
      'vehicle_plate': plate,
      'valid_from': now.toIso8601String(),
      'valid_until': now.add(const Duration(hours: 12)).toIso8601String(),
    });
    await refreshWithMessage('Invitacion creada con codigo QR.');
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage(
      {super.key,
      required this.invoices,
      required this.currency,
      required this.onPay});

  final List<dynamic> invoices;
  final NumberFormat currency;
  final Future<void> Function(Map<String, dynamic>) onPay;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Estado de cuenta',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (invoices.isEmpty)
          const EmptyState(text: 'No tienes facturas pendientes.'),
        ...invoices.map((item) {
          final invoice = item as Map<String, dynamic>;
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(invoice['invoice_number'],
                        style: Theme.of(context).textTheme.titleMedium),
                    StatusChip(text: invoice['status']),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    'Periodo ${invoice['period']} - vence ${invoice['due_date']}'),
                const SizedBox(height: 12),
                Text(currency.format(num.parse(invoice['total'].toString())),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      invoice['status'] == 'paid' ? null : () => onPay(invoice),
                  icon: const Icon(Icons.payment),
                  label: const Text('Pagar en linea'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class ReservationsPage extends StatefulWidget {
  const ReservationsPage(
      {super.key,
      required this.areas,
      required this.reservations,
      required this.currency,
      required this.onCreate});

  final List<dynamic> areas;
  final List<dynamic> reservations;
  final NumberFormat currency;
  final Future<void> Function(String areaId, DateTime startsAt, int hours)
      onCreate;

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  String? selectedAreaId;
  DateTime startsAt = DateTime.now().add(const Duration(days: 1));
  int hours = 2;

  @override
  Widget build(BuildContext context) {
    selectedAreaId ??=
        widget.areas.isNotEmpty ? widget.areas.first['id'].toString() : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Reservar zona comun',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedAreaId,
                decoration: const InputDecoration(labelText: 'Zona comun'),
                items: widget.areas.map((area) {
                  return DropdownMenuItem<String>(
                    value: area['id'].toString(),
                    child: Text(
                        '${area['name']} - ${widget.currency.format(num.parse(area['hourly_rate'].toString()))}/h'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedAreaId = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(startsAt))),
                  IconButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                        initialDate: startsAt,
                      );
                      if (date != null) {
                        setState(() => startsAt =
                            DateTime(date.year, date.month, date.day, 10));
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                  ),
                ],
              ),
              StepperControl(
                  label: 'Horas',
                  value: hours,
                  onMinus: () =>
                      setState(() => hours = hours > 1 ? hours - 1 : 1),
                  onPlus: () => setState(() => hours += 1)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: selectedAreaId == null
                    ? null
                    : () => widget.onCreate(selectedAreaId!, startsAt, hours),
                icon: const Icon(Icons.event_available),
                label: const Text('Reservar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Mis reservas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (widget.reservations.isEmpty)
          const EmptyState(text: 'Aun no tienes reservas.'),
        ...widget.reservations.map((item) {
          final reservation = item as Map<String, dynamic>;
          return AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat('dd/MM/yyyy HH:mm')
                  .format(DateTime.parse(reservation['starts_at']))),
              subtitle: Text(widget.currency
                  .format(num.parse(reservation['amount'].toString()))),
              trailing: StatusChip(text: reservation['status']),
            ),
          );
        }),
      ],
    );
  }
}

class VisitorsPage extends StatefulWidget {
  const VisitorsPage(
      {super.key, required this.visitors, required this.onCreate});

  final List<dynamic> visitors;
  final Future<void> Function(String name, String? document, String? plate)
      onCreate;

  @override
  State<VisitorsPage> createState() => _VisitorsPageState();
}

class _VisitorsPageState extends State<VisitorsPage> {
  final name = TextEditingController();
  final document = TextEditingController();
  final plate = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    document.dispose();
    plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Invitar visitante',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del visitante')),
              TextField(
                  controller: document,
                  decoration: const InputDecoration(labelText: 'Documento')),
              TextField(
                  controller: plate,
                  decoration:
                      const InputDecoration(labelText: 'Placa vehiculo')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  if (name.text.trim().isNotEmpty) {
                    widget.onCreate(name.text.trim(), document.text.trim(),
                        plate.text.trim());
                    name.clear();
                    document.clear();
                    plate.clear();
                  }
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Generar QR'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Invitaciones', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (widget.visitors.isEmpty)
          const EmptyState(text: 'No hay visitantes registrados.'),
        ...widget.visitors.map((item) {
          final visitor = item as Map<String, dynamic>;
          return AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.qr_code),
              title: Text(visitor['visitor_name']),
              subtitle: Text(visitor['qr_code']),
              trailing: StatusChip(text: visitor['status']),
            ),
          );
        }),
      ],
    );
  }
}

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key, required this.announcements});

  final List<dynamic> announcements;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Comunicados', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (announcements.isEmpty)
          const EmptyState(text: 'No hay comunicados activos.'),
        ...announcements.map((item) {
          final announcement = item as Map<String, dynamic>;
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(text: announcement['category']),
                const SizedBox(height: 8),
                Text(announcement['title'],
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(announcement['body']),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xffdce5dd))),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xffe8f4ef),
          borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xff176b5c))),
    );
  }
}

class StepperControl extends StatelessWidget {
  const StepperControl(
      {super.key,
      required this.label,
      required this.value,
      required this.onMinus,
      required this.onPlus});

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
            onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
        Text('$value'),
        IconButton(
            onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    );
  }
}
