import 'package:flutter/material.dart';
import '../../data/exchange_rate.dart';
import '../../core/supabase_client.dart';
import '../../data/receivable_loan_repository.dart';
import 'receivable_loans_page.dart';
import 'receivable_loans_summary.dart';

class ReceivableLoansDashboard extends StatefulWidget {
  const ReceivableLoansDashboard({super.key, this.refreshToken, this.onChanged, this.displayCurrency, this.exchangeRate});
  final Object? refreshToken;
  final String? displayCurrency;
  final ExchangeRate? exchangeRate;
  final VoidCallback? onChanged;
  @override
  State<ReceivableLoansDashboard> createState() => _ReceivableLoansDashboardState();
}
class _ReceivableLoansDashboardState extends State<ReceivableLoansDashboard> {
  ReceivableLoanData? data;
  bool loading = true;
  String? error;
  int requestId = 0;
  @override
  void initState() { super.initState(); loadData(); }
  @override
  void didUpdateWidget(covariant ReceivableLoansDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) { loadData(); }
  }
  Future<void> loadData() async {
    final request = ++requestId;
    setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) { throw StateError('Debes iniciar sesión nuevamente.'); }
      final result = await loadReceivableLoanData(user.id);
      if (supabase.auth.currentUser?.id != user.id) { throw StateError('La sesión cambió.'); }
      if (!mounted || request != requestId) { return; }
      setState(() { data = result; loading = false; });
    } catch (e) {
      if (mounted && request == requestId) { setState(() { error = e.toString(); loading = false; }); }
    }
  }
  Future<void> openLoans() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ReceivableLoansPage()));
    if (!mounted) { return; }
    await loadData();
    if (mounted) { widget.onChanged?.call(); }
  }
  @override
  Widget build(BuildContext context) => Card(margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12, runSpacing: 8, children: [
            const Text('Dinero que te deben', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            TextButton.icon(onPressed: openLoans, icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Préstamos por cobrar')),
          ]),
        const SizedBox(height: 12),
        if (loading) const LinearProgressIndicator()
        else if (error != null) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('No se pudo cargar el dinero por cobrar.'), SelectableText(error!),
          TextButton(onPressed: loadData, child: const Text('Reintentar')),
        ])
        else if (data != null) ReceivableLoansSummary(loans: data!.loans, payments: data!.payments,
          displayCurrency: widget.displayCurrency, exchangeRate: widget.exchangeRate),
      ])));
}
