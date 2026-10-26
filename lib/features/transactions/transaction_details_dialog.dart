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
    this.onEdit,
    this.onReconcile,
  });

  final Map<String, dynamic> transaction;
  final String account, destination, category;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onReconcile;

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
      'card_payment': 'Pago de tarjeta',
      'debt_payment': 'Abono de deuda',
    };
    final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
    final dateText = date == null
        ? 'Sin fecha'
        : '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final currency = tx['currency']?.toString() ?? 'NIO';
    final amount = moneyCents(tx['amount']);

    return AlertDialog(
      title: Text(labels[type] ?? 'Movimiento'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatMoneyCents(amount, currency),
                  style: Theme.of(context).textTheme.headlineSmall),
              const Divider(height: 24),
              _detail('Fecha', dateText),
              if (onReconcile != null)
                _detail('Conciliación',
                    tx['is_reconciled'] == true ? 'Conciliado' : 'Pendiente'),
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
        if (onReconcile != null)
          TextButton.icon(
            onPressed: onReconcile,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(tx['is_reconciled'] == true
                ? 'Quitar conciliación' : 'Conciliar'),
          ),
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

        if (onEdit != null)
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
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