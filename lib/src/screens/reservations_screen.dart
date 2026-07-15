import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/resident_api.dart';
import 'common_area_detail_screen.dart';
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
  'completed': 'Completada',
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

  Future<void> _showReceipt(String id) async {
    try {
      final receipt = await _api!.getReservationReceipt(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Comprobante'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nº ${receipt['receipt_number']}'),
              const SizedBox(height: 8),
              Text('Zona: ${receipt['zone_name']}'),
              Text('Residente: ${receipt['resident_name']}'),
              Text(
                'Horario: ${_dt.format(DateTime.parse(receipt['starts_at'].toString()).toLocal())}'
                ' → ${_dt.format(DateTime.parse(receipt['ends_at'].toString()).toLocal())}',
              ),
              Text('Monto: ${_money.format(num.parse(receipt['amount'].toString()))}'),
              Text('Estado: ${_statusLabels[receipt['status'].toString()] ?? receipt['status']}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reschedule(Map<String, dynamic> reservation) async {
    final areaId = reservation['common_area_id'].toString();
    DateTime day = DateTime.parse(reservation['starts_at'].toString()).toLocal();
    day = DateTime(day.year, day.month, day.day);
    final starts = DateTime.parse(reservation['starts_at'].toString());
    final ends = DateTime.parse(reservation['ends_at'].toString());
    final duration = ends.difference(starts).inMinutes;

    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: day.isBefore(DateTime.now()) ? DateTime.now().add(const Duration(days: 1)) : day,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
      );
      if (picked == null || !mounted) return;
      final onDate = DateTime(picked.year, picked.month, picked.day);
      final availability = await _api!.getAvailability(
        areaId: areaId,
        date: onDate,
        durationMinutes: duration,
        excludeReservationId: reservation['id'].toString(),
      );
      if (!mounted) return;
      final slots = ((availability['slots'] as List?) ?? [])
          .cast<dynamic>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (slots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay franjas disponibles ese día.')),
        );
        return;
      }
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Elige nuevo horario'),
          children: [
            for (final slot in slots)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, slot),
                child: Text(
                  '${DateFormat('HH:mm').format(DateTime.parse(slot['starts_at'].toString()).toLocal())}'
                  ' – ${DateFormat('HH:mm').format(DateTime.parse(slot['ends_at'].toString()).toLocal())}',
                ),
              ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      await _api!.rescheduleReservation(
        reservationId: reservation['id'].toString(),
        startsAt: DateTime.parse(selected['starts_at'].toString()),
        endsAt: DateTime.parse(selected['ends_at'].toString()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva reprogramada')));
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
        final active = status == 'requested' || status == 'approved';
        final hasReceipt = status == 'approved' || status == 'paid' || status == 'completed';
        final label = _statusLabels[status] ?? status;
        final receipt = r['receipt_number']?.toString();

        return Card(
          child: ListTile(
            title: Text(areaName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${_dt.format(starts)} → ${_dt.format(ends)}\n'
              'Estado: $label · ${_money.format(amount)}'
              '${receipt != null && receipt.isNotEmpty ? ' · $receipt' : ''}',
            ),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 0,
              children: [
                if (hasReceipt)
                  IconButton(
                    tooltip: 'Comprobante',
                    onPressed: () => _showReceipt(r['id'].toString()),
                    icon: const Icon(Icons.receipt_long_outlined),
                  ),
                if (active)
                  IconButton(
                    tooltip: 'Reprogramar',
                    onPressed: () => _reschedule(r),
                    icon: const Icon(Icons.event_repeat),
                  ),
                if (active)
                  IconButton(
                    tooltip: 'Cancelar',
                    onPressed: () => _cancel(r['id'].toString()),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  ),
                IconButton(
                  tooltip: 'Ver zona',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommonAreaDetailScreen(areaId: r['common_area_id'].toString()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
