import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/person_account_repository.dart';

enum ReceiptFilter {
  all('Todos'),
  withReceipt('Con comprobante'),
  withoutReceipt('Sin comprobante');

  const ReceiptFilter(this.label);
  final String label;

  bool matches(int count) => switch (this) {
    all => true,
    withReceipt => count > 0,
    withoutReceipt => count == 0,
  };
}

typedef FinancialReceiptRef = ({String table, String id});

FinancialReceiptRef? financialReceiptRef(Map<String, dynamic> row) {
  final id = row['id']?.toString();
  if (id == null || id.isEmpty) return null;
  final parts = id.split(':');
  return switch (row['source']) {
    'credit_card_payment' => (table: 'credit_card_transactions', id: id),
    'debt_payment' => (table: 'debt_payments', id: id),
    'fx_transfer' => (table: 'app_fx_transfers', id: id),
    'receivable_loan' when parts.length >= 3 => (
      table: parts[1] == 'payment'
          ? 'receivable_loan_payments'
          : 'receivable_loans',
      id: parts[2],
    ),
    'receivable_loan' => null,
    _ => (table: 'transactions', id: id),
  };
}

String? financialReceiptFolder(Map<String, dynamic> row) {
  final ref = financialReceiptRef(row);
  return ref == null ? null : '${ref.table}/${ref.id}';
}

Future<Map<String, int>> loadReceiptCounts(
  String uid,
  String bucket,
  Iterable<String> folders,
) async {
  final paths = folders.toSet().toList();
  final counts = <String, int>{};
  for (var start = 0; start < paths.length; start += 100) {
    checkPersonSession(uid);
    final rows =
        await supabase.rpc(
              'receipt_counts',
              params: {
                'p_bucket': bucket,
                'p_folders': paths.skip(start).take(100).toList(),
              },
            )
            as List;
    checkPersonSession(uid);
    for (final row in rows) {
      counts[row['folder'] as String] = (row['total'] as num).toInt();
    }
  }
  return counts;
}

class ReceiptFilterField extends StatelessWidget {
  const ReceiptFilterField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ReceiptFilter value;
  final ValueChanged<ReceiptFilter> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<ReceiptFilter>(
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Comprobantes',
      prefixIcon: Icon(Icons.attach_file),
    ),
    items: [
      for (final filter in ReceiptFilter.values)
        DropdownMenuItem(value: filter, child: Text(filter.label)),
    ],
    onChanged: (filter) {
      if (filter != null) onChanged(filter);
    },
  );
}
