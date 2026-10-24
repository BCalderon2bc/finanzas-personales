import 'package:flutter/material.dart';
import '../../utils/money.dart';

class TransactionDetailsDialog extends StatelessWidget {
  const TransactionDetailsDialog({
    super.key,
    required this.transaction,
    required this.account,
    required this.destination,
    required this.category,
    this.onDelete,
  });

  final Map<String, dynamic> transaction;
  final String account, destination, category;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final type = tx['transaction_type']?.toString() ?? '';
    const labels = {
      'income': 'Ingreso',
      'expense': 'Gasto',
      'transfer': 'Transferencia',
      'deposit': 'Depósito',
      'withdrawal': 'Retiro',
      'adjustment': 'Ajuste',
    };
    final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
    final dateText = date == null
        ? 'Sin fecha'
        : '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final currency = tx['currency']?.toString() ?? 'NIO';
    final symbol = currency == 'USD' ? 'US\$' : 'C\$';
    final amount = moneyCents(tx['amount']) / 100;

    return AlertDialog(
      title: Text(labels[type] ?? 'Movimiento'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$symbol ${amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Divider(height: 24),
              _detail('Fecha', dateText),
              _detail(type == 'transfer' ? 'Cuenta de origen' : 'Cuenta', account),
              if (type == 'transfer') _detail('Cuenta de destino', destination),
              _detail('Categoría', category),
              _detail('Descripción', tx['description']?.toString()),
              _detail('Referencia', tx['reference']?.toString()),
            ],
          ),
        ),
      ),
      actions: [
        if (onDelete != null)
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
      ],
    );
  }

  Widget _detail(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      SelectableText((value ?? '').trim().isEmpty ? 'Sin especificar' : value!.trim()),
    ]),
  );
}