import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/resident_api.dart';

class CommonAreaDetailScreen extends StatefulWidget {
  const CommonAreaDetailScreen({super.key, required this.areaId});

  final String areaId;

  @override
  State<CommonAreaDetailScreen> createState() => _CommonAreaDetailScreenState();
}

class _CommonAreaDetailScreenState extends State<CommonAreaDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  static const _weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  void initState() {
    super.initState();
    _future = context.read<ResidentApi>().getCommonArea(widget.areaId);
  }

  String _money(dynamic value) {
    final n = num.tryParse('$value') ?? 0;
    return NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0).format(n);
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
                  Chip(label: Text(hasCost ? '${_money(area['hourly_rate'])}/h' : 'Sin costo')),
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
              Text('Condiciones de reserva', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Duración: ${area['min_duration_minutes']}–${area['max_duration_minutes']} min'),
              Text('Anticipación: mín ${area['min_advance_minutes']} min · máx ${area['max_advance_days']} días'),
              Text('Buffer limpieza: ${area['cleanup_buffer_minutes']} min'),
              if (area['requires_approval'] == true) const Text('Requiere aprobación administrativa.'),
              const SizedBox(height: 16),
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
              ],
              if (!bookable)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Esta zona es solo informativa. No admite reservas desde la app.'),
                ),
            ],
          );
        },
      ),
    );
  }
}
