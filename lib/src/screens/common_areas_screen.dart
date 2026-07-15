import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/resident_api.dart';
import 'common_area_detail_screen.dart';

class CommonAreasScreen extends StatefulWidget {
  const CommonAreasScreen({super.key});

  @override
  State<CommonAreasScreen> createState() => _CommonAreasScreenState();
}

class _CommonAreasScreenState extends State<CommonAreasScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ResidentApi>().listCommonAreas();
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<ResidentApi>().listCommonAreas();
    });
    await _future;
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
        title: const Text('Zonas Sociales'),
        backgroundColor: const Color(0xff176b5c),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final areas = snapshot.data ?? [];
          if (areas.isEmpty) {
            return const Center(child: Text('No hay zonas sociales disponibles.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: areas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final area = areas[index];
              final bookable = area['is_bookable'] == true;
              final hasCost = area['has_cost'] == true || (num.tryParse('${area['hourly_rate']}') ?? 0) > 0;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(area['name']?.toString() ?? 'Zona', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('${area['category'] ?? 'general'} · Capacidad ${area['capacity'] ?? '-'}'),
                      const SizedBox(height: 4),
                      Text(
                        bookable
                            ? (hasCost ? 'Reservable · ${_money(area['hourly_rate'])}/h' : 'Reservable · Sin costo')
                            : 'Solo informativa',
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommonAreaDetailScreen(areaId: area['id'].toString()),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
