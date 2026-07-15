import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/resident_api.dart';

class CommonAreaDetailScreen extends StatefulWidget {
  const CommonAreaDetailScreen({super.key, required this.areaId});

  final String areaId;

  @override
  State<CommonAreaDetailScreen> createState() => _CommonAreaDetailScreenState();
}

class _CommonAreaDetailScreenState extends State<CommonAreaDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  late final ResidentApi _api;

  static const _weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  final _money = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
  final _time = DateFormat('HH:mm');

  DateTime _selectedDay = DateTime.now().add(const Duration(days: 1));
  int _durationMinutes = 60;
  List<Map<String, dynamic>> _slots = [];
  bool _loadingSlots = false;
  String? _slotsError;

  @override
  void initState() {
    super.initState();
    _api = context.read<ResidentApi>();
    _future = _api.getCommonArea(widget.areaId);
    _selectedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
  }

  String _moneyFmt(dynamic value) {
    final n = num.tryParse('$value') ?? 0;
    return _money.format(n);
  }

  Future<void> _loadSlots(Map<String, dynamic> area) async {
    if (area['is_bookable'] != true) return;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });
    try {
      final result = await _api.getAvailability(
        areaId: widget.areaId,
        date: _selectedDay,
        durationMinutes: _durationMinutes,
      );
      if (!mounted) return;
      final slots = ((result['slots'] as List?) ?? []).cast<dynamic>().map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slotsError = e.toString();
        _loadingSlots = false;
        _slots = [];
      });
    }
  }

  Future<void> _book(Map<String, dynamic> slot) async {
    final auth = context.read<AuthProvider>();
    final residentId = auth.user?.residentId;
    if (residentId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar reserva'),
        content: Text(
          '${_time.format(DateTime.parse(slot['starts_at'].toString()).toLocal())} – '
          '${_time.format(DateTime.parse(slot['ends_at'].toString()).toLocal())}\n'
          'Costo estimado: ${_moneyFmt(slot['amount'])}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reservar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api.createReservation(
        residentId: residentId,
        commonAreaId: widget.areaId,
        startsAt: DateTime.parse(slot['starts_at'].toString()),
        endsAt: DateTime.parse(slot['ends_at'].toString()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva creada')));
      final area = await _future;
      await _loadSlots(area);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7f2),
      appBar: AppBar(
        title: const Text('Detalle de zona'),
        backgroundColor: const Color(0xff176b5c),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final area = snapshot.data ?? {};
          final images = (area['images'] as List?) ?? [];
          final schedules = (area['schedules'] as List?) ?? [];
          final bookable = area['is_bookable'] == true;
          final hasCost = area['has_cost'] == true || (num.tryParse('${area['hourly_rate']}') ?? 0) > 0;
          final minDur = int.tryParse('${area['min_duration_minutes']}') ?? 60;
          final maxDur = int.tryParse('${area['max_duration_minutes']}') ?? 240;
          if (_durationMinutes < minDur || _durationMinutes > maxDur) {
            _durationMinutes = minDur;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (images.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: PageView(
                    children: [
                      for (final img in images)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            img['url']?.toString() ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Text('No se pudo cargar la imagen'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (images.isNotEmpty) const SizedBox(height: 16),
              Text(area['name']?.toString() ?? 'Zona', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${area['category'] ?? 'general'}')),
                  Chip(label: Text(bookable ? 'Reservable' : 'Informativa')),
                  Chip(label: Text(hasCost ? '${_moneyFmt(area['hourly_rate'])}/h' : 'Sin costo')),
                  Chip(label: Text('Capacidad ${area['capacity'] ?? '-'}')),
                ],
              ),
              const SizedBox(height: 12),
              if ((area['description']?.toString() ?? '').isNotEmpty) ...[
                Text(area['description'].toString()),
                const SizedBox(height: 16),
              ],
              Text('Reglamento', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text((area['rules']?.toString().isNotEmpty == true) ? area['rules'].toString() : 'Sin reglamento publicado.'),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final docs = ((area['required_documents'] as List?) ?? []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
                  if (docs.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Documentos requeridos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ...docs.map((d) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined, size: 20),
                            title: Text(d),
                          )),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              if (schedules.isNotEmpty) ...[
                Text('Horarios', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...schedules.map((s) {
                  final weekday = int.tryParse('${s['weekday']}') ?? 0;
                  final closed = s['is_closed'] == true;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_weekdays[weekday.clamp(0, 6)]),
                    subtitle: Text(closed ? 'Cerrado' : '${s['open_time']} – ${s['close_time']}'),
                  );
                }),
                const SizedBox(height: 8),
              ],
              if (!bookable)
                const Text('Esta zona es solo informativa. No admite reservas desde la app.')
              else ...[
                Text('Reservar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(_selectedDay)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDay,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: int.tryParse('${area['max_advance_days']}') ?? 90)),
                    );
                    if (picked == null) return;
                    setState(() => _selectedDay = DateTime(picked.year, picked.month, picked.day));
                    await _loadSlots(area);
                  },
                ),
                DropdownButtonFormField<int>(
                  value: _durationMinutes.clamp(minDur, maxDur),
                  decoration: const InputDecoration(labelText: 'Duración (minutos)'),
                  items: [
                    for (var m = minDur; m <= maxDur; m += (minDur >= 30 ? minDur : 30))
                      DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _durationMinutes = v);
                    await _loadSlots(area);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _loadingSlots ? null : () => _loadSlots(area),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xff176b5c)),
                    child: Text(_loadingSlots ? 'Buscando...' : 'Ver horarios disponibles'),
                  ),
                ),
                if (_slotsError != null) ...[
                  const SizedBox(height: 8),
                  Text(_slotsError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                if (_slots.isEmpty && !_loadingSlots)
                  const Text('Sin franjas disponibles para ese día.')
                else
                  ..._slots.map((slot) {
                    final start = DateTime.parse(slot['starts_at'].toString()).toLocal();
                    final end = DateTime.parse(slot['ends_at'].toString()).toLocal();
                    return Card(
                      child: ListTile(
                        title: Text('${_time.format(start)} – ${_time.format(end)}'),
                        subtitle: Text(_moneyFmt(slot['amount'])),
                        trailing: FilledButton(
                          onPressed: () => _book(slot),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xff176b5c)),
                          child: const Text('Reservar'),
                        ),
                      ),
                    );
                  }),
              ],
            ],
          );
        },
      ),
    );
  }
}
