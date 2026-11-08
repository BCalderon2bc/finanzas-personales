import 'package:flutter/material.dart';

import '../../utils/money.dart';
import '../transactions/transaction_form_dialog.dart';

class MovementPracticePage extends StatefulWidget {
  const MovementPracticePage({super.key});

  @override
  State<MovementPracticePage> createState() => _MovementPracticePageState();
}

class _MovementPracticePageState extends State<MovementPracticePage> {
  static const accounts = <Map<String, dynamic>>[
    {'id': 'demo-nio', 'name': 'Efectivo de ejemplo', 'currency': 'NIO'},
    {'id': 'demo-usd', 'name': 'Ahorro de ejemplo', 'currency': 'USD'},
  ];
  static const categories = <Map<String, dynamic>>[
    {'id': 'demo-food', 'name': 'Comida', 'category_type': 'expense'},
    {'id': 'demo-pay', 'name': 'Salario', 'category_type': 'income'},
  ];
  Map<String, dynamic>? movement;
  bool edited = false;

  Future<void> openForm({bool editing = false}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TransactionFormDialog(
        practice: true,
        accounts: accounts,
        categories: categories,
        transaction: editing ? movement : null,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      movement = result;
      edited = editing;
    });
  }

  String accountName(Object? id) =>
      accounts.firstWhere((account) => account['id'] == id)['name'] as String;

  @override
  Widget build(BuildContext context) {
    final row = movement;
    final type = switch (row?['transaction_type']) {
      'income' => 'Ingreso',
      'transfer' => 'Transferencia',
      _ =>
        row?['expense_kind'] == 'card_insurance'
            ? 'Seguro de tarjeta'
            : 'Gasto',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Practicar con un movimiento')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Modo práctica',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usa las cuentas de ejemplo para crear un movimiento. '
                  'Después puedes editarlo y ver el cambio. '
                  'La simulación se descarta al salir de esta pantalla.',
                ),
                const SizedBox(height: 16),
                if (row == null)
                  FilledButton.icon(
                    onPressed: () => openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear movimiento de práctica'),
                  )
                else ...[
                  Card(
                    child: ListTile(
                      title: Text(row['description']?.toString() ?? type),
                      subtitle: Text(
                        [
                          type,
                          accountName(row['account_id']),
                          if (row['destination_account_id'] != null)
                            'Destino · ${accountName(row['destination_account_id'])}',
                          formatMoneyCents(
                            moneyCents(row['amount']),
                            '${row['currency']}',
                          ),
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(edited ? 'Simulación actualizada' : 'Simulación creada'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => openForm(editing: true),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar movimiento de práctica'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
