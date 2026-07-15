import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/resident_api.dart';

final _money = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _dt = DateFormat('dd/MM/yyyy HH:mm');

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  ResidentApi? _api;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _areas = [];
  Map<String, String> _areaNames = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      _api = ResidentApi(context.read<ApiClient>());
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api!.listReservations(),
        _api!.listCommonAreas(),
      ]);
      if (!mounted) return;
      final areas = results[1];
      setState(() {
        _reservations = results[0];
        _areas = areas;
        _areaNames = {
          for (final a in areas) a['id'].toString(): a['name'].toString(),
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createReservation() async {
    if (_areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay zonas comunes disponibles')),
      );
      return;
    }

    String areaId = _areas.first['id'].toString();
    DateTime startsAt = DateTime.now().add(const Duration(days: 1));
    startsAt = DateTime(startsAt.year, startsAt.month, startsAt.day, 10);
    int hours = 2;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Nueva reserva'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: areaId,
                      decoration: const InputDecoration(labelText: 'Zona común'),
                      items: _areas
                          .map(
                            (a) => DropdownMenuItem(
                              value: a['id'].toString(),
                              child: Text(
                                '${a['name']} (${_money.format(num.parse(a['hourly_rate'].toString()))}/h)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => areaId = v!),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Inicio: ${_dt.format(startsAt)}'),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startsAt,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startsAt),
                        );
                        if (time == null) return;
                        setLocal(() {
                          startsAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                    DropdownButtonFormField<int>(
                      value: hours,
                      decoration: const InputDecoration(labelText: 'Duración (horas)'),
                      items: [1, 2, 3, 4]
                          .map((h) => DropdownMenuItem(value: h, child: Text('$h')))
                          .toList(),
                      onChanged: (v) => setLocal(() => hours = v ?? 2),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reservar')),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;
    final residentId = context.read<AuthProvider>().user?.residentId;
    if (residentId == null) return;

    try {
      await _api!.createReservation(
        residentId: residentId,
        commonAreaId: areaId,
        startsAt: startsAt,
        endsAt: startsAt.add(Duration(hours: hours)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva creada')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text('¿Confirmas cancelar esta reserva?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api!.cancelReservation(id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _createReservation,
        backgroundColor: const Color(0xff176b5c),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Reservar'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xff176b5c)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_reservations.isEmpty) {
      return const Center(child: Text('Aún no tienes reservas.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _reservations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = _reservations[index];
        final status = r['status'].toString();
        final areaName = _areaNames[r['common_area_id'].toString()] ?? 'Zona';
        final starts = DateTime.parse(r['starts_at'].toString()).toLocal();
        final ends = DateTime.parse(r['ends_at'].toString()).toLocal();
        final amount = num.parse(r['amount'].toString());
        final cancellable = status == 'requested' || status == 'approved' || status == 'waitlisted';

        return Card(
          child: ListTile(
            title: Text(areaName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${_dt.format(starts)} → ${_dt.format(ends)}\n'
              'Estado: $status · ${_money.format(amount)}',
            ),
            isThreeLine: true,
            trailing: cancellable
                ? IconButton(
                    tooltip: 'Cancelar',
                    onPressed: () => _cancel(r['id'].toString()),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  )
                : null,
          ),
        );
      },
    );
  }
}
