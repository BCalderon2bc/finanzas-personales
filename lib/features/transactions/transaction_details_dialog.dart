import '../person_accounts/receipt_history.dart';
import 'package:flutter/material.dart';
import '../person_accounts/person_receipts_dialog.dart';
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
  });

  final Map<String, dynamic> transaction;
  final String account, destination, category;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final receipt = financialReceiptRef(tx);
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
    final source = tx['source'];
    final linkedPayment =
        source == 'credit_card_payment' || source == 'debt_payment';
    final receivable = source == 'receivable_loan';
    final title = linkedPayment
        ? (source == 'debt_payment'
              ? 'Detalle del abono de deuda'
              : 'Detalle del pago de tarjeta')
        : receivable
        ? (type == 'withdrawal' ? 'Detalle del préstamo' : 'Detalle del cobro')
        : labels[type] ?? 'Movimiento';
    final insurance = moneyCents(tx['insurance_amount'] ?? 0);
    String money(Object? value) =>
        formatMoneyCents(moneyCents(value ?? 0), currency);

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMoneyCents(amount, currency),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(height: 24),
              _detail('Fecha', dateText),
              _detail(
                type == 'transfer' ? 'Cuenta de origen' : 'Cuenta',
                account,
              ),
              if (type == 'transfer') _detail('Cuenta de destino', destination),
              if (tx['destination_amount'] != null) ...[
                _detail(
                  'Monto recibido',
                  formatMoneyCents(
                    moneyCents(tx['destination_amount']),
                    '${tx['destination_currency']}',
                  ),
                ),
                _detail('Tasa C\$ por \$ 1', '${tx['exchange_rate']}'),
              ],
              if (source == 'credit_card_payment') ...[
                _detail(
                  'Aplicado a la tarjeta',
                  formatMoneyCents(
                    moneyCents(tx['card_amount'] ?? tx['amount']),
                    '${tx['card_currency'] ?? currency}',
                  ),
                ),
                if (tx['payment_exchange_rate'] != null)
                  _detail('Tasa de cambio', '${tx['payment_exchange_rate']}'),
              ],
              if (source == 'debt_payment' || receivable) ...[
                if (tx['payment_total'] != null)
                  _detail('Total del cobro', money(tx['payment_total'])),
                _detail('Capital', money(tx['principal_amount'])),
                if (tx['interest_amount'] != null)
                  _detail('Intereses', money(tx['interest_amount'])),
                if (insurance != 0)
                  _detail('Seguro', formatMoneyCents(insurance, currency)),
                if (tx['fee_amount'] != null)
                  _detail(
                    'Comisiones y otros cargos',
                    formatMoneyCents(
                      moneyCents(tx['fee_amount']) - insurance,
                      currency,
                    ),
                  ),
              ],
              if (category.isNotEmpty) _detail('Categoría', category),
              if (tx['expense_kind'] == 'card_insurance')
                _detail('Tipo de gasto', 'Seguro de tarjeta'),
              _detail('Descripción', tx['description']?.toString()),
              _detail('Referencia', tx['reference']?.toString()),
              if (receipt != null)
                MovementReceiptsButton(
                  table: receipt.table,
                  record: {...tx, 'id': receipt.id},
                ),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),

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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        SelectableText(
          (value ?? '').trim().isEmpty ? 'Sin especificar' : value!.trim(),
        ),
      ],
    ),
  );
}
