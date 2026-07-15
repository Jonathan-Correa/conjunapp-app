import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/resident_api.dart';
import 'common_areas_screen.dart';

final _money = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
final _dt = DateFormat('dd/MM/yyyy HH:mm');

const _statusLabels = {
  'requested': 'Solicitada',
  'approved': 'Aprobada',
  'paid': 'Pagada',
  'waitlisted': 'En lista',
  'cancelled': 'Cancelada',
  'rescheduled': 'Reprogramada',
  'rejected': 'Rechazada',
};

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

  Future<void> _openCatalog() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommonAreasScreen()));
    if (mounted) await _load();
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
        onPressed: _loading ? null : _openCatalog,
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
      return const Center(child: Text('Aún no tienes reservas. Usa Reservar para ver zonas sociales.'));
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
        final label = _statusLabels[status] ?? status;

        return Card(
          child: ListTile(
            title: Text(areaName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${_dt.format(starts)} → ${_dt.format(ends)}\n'
              'Estado: $label · ${_money.format(amount)}',
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
