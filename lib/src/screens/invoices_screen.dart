import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/resident_api.dart';

final _money = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  ResidentApi? _api;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _invoices = [];
  bool _onlyOpen = true;

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
      final items = await _api!.listInvoices(onlyOpen: _onlyOpen);
      if (!mounted) return;
      setState(() {
        _invoices = items;
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

  Future<void> _pay(Map<String, dynamic> invoice) async {
    final total = num.parse(invoice['total'].toString());
    final paid = num.parse(invoice['paid_amount'].toString());
    final remaining = total - paid;
    if (remaining <= 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar pago'),
        content: Text(
          '¿Registrar pago PSE de ${_money.format(remaining)} para ${invoice['invoice_number']}?\n\n'
          '(Simulación: no hay pasarela real aún.)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pagar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _api!.payInvoice(invoiceId: invoice['id'].toString(), amount: remaining);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado correctamente')),
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
        title: const Text('Mis facturas'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Solo abiertas / pendientes'),
            value: _onlyOpen,
            activeColor: const Color(0xff176b5c),
            onChanged: (v) {
              setState(() => _onlyOpen = v);
              _load();
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
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
    if (_invoices.isEmpty) {
      return const Center(child: Text('No hay facturas para mostrar.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final total = num.parse(inv['total'].toString());
        final paid = num.parse(inv['paid_amount'].toString());
        final remaining = total - paid;
        final status = inv['status'].toString();
        final canPay = remaining > 0 && status != 'cancelled';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        inv['invoice_number'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Chip(
                      label: Text(status),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: status == 'paid'
                          ? const Color(0xffe5f5eb)
                          : const Color(0xfffff3cd),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Periodo: ${inv['period']}'),
                Text('Vence: ${inv['due_date']}'),
                Text('Total: ${_money.format(total)}'),
                Text('Pagado: ${_money.format(paid)}'),
                Text('Saldo: ${_money.format(remaining)}'),
                if (canPay) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _pay(inv),
                      icon: const Icon(Icons.payment),
                      label: const Text('Pagar saldo'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xff176b5c)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
