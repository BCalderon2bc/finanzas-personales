import 'package:flutter/material.dart';
import '../../data/movement_totals.dart';
import '../../utils/money.dart';
import '../../widgets/adaptive_layout.dart';

class MovementTotalsPanel extends StatelessWidget {
  const MovementTotalsPanel({
    super.key,
    required this.rows,
    required this.selectedType,
  });
  final List<Map<String, dynamic>> rows;
  final String selectedType;
  @override
  Widget build(BuildContext context) {
    final totals = movementTotals(rows);
    bool show(String type) => selectedType == 'all' || selectedType == type;
    final expenseLabel = selectedType == 'insurance'
        ? 'Seguro de tarjeta'
        : 'Gastos netos';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Totales de esta búsqueda · ${rows.length} movimientos',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ),
        AdaptiveColumns(
          minColumnWidth: 280,
          children: [
            for (final c in ['NIO', 'USD'])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        c == 'USD' ? 'Dólares' : 'Córdobas',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (show('income'))
                        Text(
                          'Ingresos: ${formatMoneyCents(totals[c]!.income, c)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      if (show('expense') || selectedType == 'insurance')
                        Text(
                          '$expenseLabel: ${formatMoneyCents(totals[c]!.expenses, c)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      if (show('card_payment'))
                        Text(
                          'Pagos de tarjeta: ${formatMoneyCents(totals[c]!.cardPayments, c)}',
                        ),
                      if (show('debt_payment'))
                        Text(
                          'Abonos de deudas: ${formatMoneyCents(totals[c]!.debtPayments, c)}',
                        ),
                      if (show('transfer'))
                        Text(
                          'Transferencias enviadas: ${formatMoneyCents(totals[c]!.transfers, c)}',
                        ),
                      if (show('deposit'))
                        Text(
                          'Depósitos: ${formatMoneyCents(totals[c]!.deposits, c)}',
                        ),
                      if (show('withdrawal'))
                        Text(
                          'Retiros: ${formatMoneyCents(totals[c]!.withdrawals, c)}',
                        ),
                      if (show('adjustment'))
                        Text(
                          'Ajustes: ${formatMoneyCents(totals[c]!.adjustments, c)}',
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (selectedType == 'all')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Importes originales por moneda de cada registro. Los gastos incluyen intereses y cargos de abonos. Transferencias, capital y pagos de tarjeta se muestran aparte. Los totales usan todos los filtros de esta lista.',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
