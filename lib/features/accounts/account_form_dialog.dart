import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';

class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({super.key, this.account});
  final Map<String, dynamic>? account;
  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}
class _AccountFormDialogState extends State<AccountFormDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(), balanceController = TextEditingController(text: '0.00');
  final referenceController = TextEditingController(), notesController = TextEditingController();
  String accountType = 'savings', currency = 'NIO';
  String? institutionId, institutionError;
  List<Map<String, dynamic>> institutions = [];
  bool loadingInstitutions = true;
  bool get editing => widget.account != null;
  bool get requiresInstitution => accountType == 'savings' || accountType == 'checking';
  static const types = {'savings': 'Cuenta de ahorro', 'checking': 'Cuenta corriente', 'cash': 'Efectivo',
    'wallet': 'Billetera digital', 'investment': 'Inversión', 'other': 'Otra cuenta'};
  @override
  void initState() {
    super.initState();
    final account = widget.account;
    if (account != null) {
      nameController.text = account['name']?.toString() ?? '';
      balanceController.text = account['opening_balance'].toString();
      referenceController.text = account['account_reference']?.toString() ?? '';
      notesController.text = account['notes']?.toString() ?? '';
      accountType = account['account_type'].toString();
      currency = account['currency'].toString();
      institutionId = account['institution_id']?.toString();
    }
    loadInstitutions();
  }
  @override
  void dispose() {
    nameController.dispose(); balanceController.dispose(); referenceController.dispose(); notesController.dispose();
    super.dispose();
  }
  Future<void> loadInstitutions() async {
    setState(() { loadingInstitutions = true; institutionError = null; });
    try {
      final result = await supabase.from('financial_institutions').select('id, name')
          .eq('is_active', true).order('name');
      final rows = List<Map<String, dynamic>>.from(result);
      if (institutionId != null && !rows.any((row) => row['id'].toString() == institutionId)) {
        final current = widget.account?['financial_institutions'];
        rows.add({'id': institutionId, 'name': '${current is Map ? current['name'] ?? 'Institución' : 'Institución'} (actual)'});
      }
      if (mounted) setState(() { institutions = rows; loadingInstitutions = false; });
    } catch (e) {
      if (mounted) setState(() { institutionError = e.toString(); loadingInstitutions = false; });
    }
  }
  void save() {
    if (!formKey.currentState!.validate()) return;
    final data = <String, dynamic>{
      'name': nameController.text.trim(), 'institution_id': institutionId,
      'account_reference': referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
      'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
    };
    if (!editing) {
      data.addAll({'account_type': accountType, 'currency': currency,
        'opening_balance': double.parse(balanceController.text.trim().replaceAll(',', '.'))});
    }
    Navigator.pop(context, data);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(editing ? 'Editar cuenta' : 'Nueva cuenta'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: formKey,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(controller: nameController, autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre de la cuenta *'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre para la cuenta' : null),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: accountType, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo de cuenta'),
          items: types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: editing ? null : (v) {
            if (v != null) setState(() { accountType = v; if (!requiresInstitution) institutionId = null; });
          }),
        if (requiresInstitution || institutionId != null) ...[
          const SizedBox(height: 12),
          if (loadingInstitutions) const LinearProgressIndicator()
          else if (institutionError != null) ...[
            Text('No se pudieron cargar los bancos: $institutionError'),
            TextButton(onPressed: loadInstitutions, child: const Text('Reintentar')),
          ] else DropdownButtonFormField<String>(value: institutionId ?? 'none', isExpanded: true,
            decoration: const InputDecoration(labelText: 'Banco o institución'),
            items: [const DropdownMenuItem(value: 'none', child: Text('Sin institución')),
              ...institutions.map((i) => DropdownMenuItem(value: i['id'].toString(),
                child: Text(i['name'].toString(), overflow: TextOverflow.ellipsis)))],
            onChanged: (v) => setState(() => institutionId = v == 'none' ? null : v)),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: currency, decoration: const InputDecoration(labelText: 'Moneda'),
          items: const [DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
            DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)'))],
          onChanged: editing ? null : (v) { if (v != null) setState(() => currency = v); }),
        const SizedBox(height: 12),
        TextFormField(controller: balanceController, readOnly: editing,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Saldo inicial'),
          validator: (v) {
            if (editing) return null;
            final amount = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
            if (amount == null || !amount.isFinite || amount < 0) return 'Introduce un saldo válido';
            if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch((v ?? '').trim())) return 'Usa como máximo dos decimales, sin separadores de miles';
            return null;
          }),
        if (editing) const Padding(padding: EdgeInsets.only(top: 8),
          child: Text('El tipo, la moneda y el saldo inicial se conservan al editar.')),
        const SizedBox(height: 12),
        TextFormField(controller: referenceController, decoration: const InputDecoration(
          labelText: 'Número o referencia (opcional)', helperText: 'No ingreses el PIN ni la contraseña bancaria.')),
        const SizedBox(height: 12),
        TextFormField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas (opcional)')),
      ]),
    ))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: save, child: const Text('Guardar'))],
  );
}
