import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/resident_api.dart';

final _dt = DateFormat('dd/MM/yyyy HH:mm');

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key});

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  ResidentApi? _api;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _visitors = [];

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
      final items = await _api!.listVisitors();
      if (!mounted) return;
      setState(() {
        _visitors = items;
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

  Future<void> _createVisitor() async {
    final nameCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final validFrom = DateTime.now();
    final validUntil = DateTime.now().add(const Duration(hours: 4));

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Invitar visitante'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: docCtrl,
                  decoration: const InputDecoration(labelText: 'Documento (opcional)'),
                ),
                TextField(
                  controller: plateCtrl,
                  decoration: const InputDecoration(labelText: 'Placa (opcional)'),
                ),
                const SizedBox(height: 8),
                Text('Desde: ${_dt.format(validFrom)}', style: const TextStyle(fontSize: 13)),
                Text('Hasta: ${_dt.format(validUntil)}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    final name = nameCtrl.text.trim();
    final document = docCtrl.text.trim();
    final plate = plateCtrl.text.trim();
    nameCtrl.dispose();
    docCtrl.dispose();
    plateCtrl.dispose();

    if (ok != true || !mounted || name.isEmpty) return;
    final residentId = context.read<AuthProvider>().user?.residentId;
    if (residentId == null) return;

    try {
      final visitor = await _api!.createVisitor(
        residentId: residentId,
        visitorName: name,
        documentNumber: document.isEmpty ? null : document,
        vehiclePlate: plate.isEmpty ? null : plate,
        validFrom: validFrom,
        validUntil: validUntil,
      );
      if (!mounted) return;
      final qr = visitor['qr_code']?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invitación creada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Visitante: $name'),
              const SizedBox(height: 8),
              SelectableText(qr, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Código QR (texto). Muéstralo en portería.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qr));
                Navigator.pop(context);
              },
              child: const Text('Copiar y cerrar'),
            ),
          ],
        ),
      );
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
        title: const Text('Visitantes'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _createVisitor,
        backgroundColor: const Color(0xff176b5c),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invitar'),
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
    if (_visitors.isEmpty) {
      return const Center(child: Text('No hay invitaciones registradas.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _visitors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final v = _visitors[index];
        final from = DateTime.parse(v['valid_from'].toString()).toLocal();
        final until = DateTime.parse(v['valid_until'].toString()).toLocal();
        final qr = v['qr_code']?.toString() ?? '';

        return Card(
          child: ListTile(
            title: Text(v['visitor_name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${_dt.format(from)} → ${_dt.format(until)}\n'
              'QR: $qr · Estado: ${v['status']}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Copiar QR',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qr));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR copiado')),
                );
              },
              icon: const Icon(Icons.qr_code_2),
            ),
          ),
        );
      },
    );
  }
}
