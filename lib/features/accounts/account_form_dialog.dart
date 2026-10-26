import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import 'account_card.dart';
import 'account_design_fields.dart';

class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({super.key, this.account});
  final Map<String, dynamic>? account;
  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final balanceController = TextEditingController(text: '0.00');
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  String accountType = 'savings', currency = 'NIO';
  String? institutionId, institutionError;
  List<Map<String, dynamic>> institutions = [];
  Map<String, dynamic> cardDesign = {};
  bool loadingInstitutions = true;
  bool get editing => widget.account != null;
  bool get supportsDebit => ['savings', 'checking'].contains(accountType);
  bool get requiresInstitution => supportsDebit;
  bool get canSave => !requiresInstitution ||
      (!loadingInstitutions && institutionError == null);

  static const types = {
    'savings': 'Cuenta de ahorro', 'checking': 'Cuenta corriente',
    'cash': 'Efectivo', 'wallet': 'Billetera digital',
    'investment': 'Inversión', 'other': 'Otra cuenta',
  };

  Map<String, dynamic> get preview {
    final banks = institutions.where((b) => b['id'].toString() == institutionId);
    final original = widget.account;
    dynamic institution;
    if (institutionId != null) {
      if (banks.isNotEmpty) {
        institution = banks.first;
      } else if (original != null &&
          institutionId == original['institution_id']?.toString()) {
        institution = original['financial_institutions'];
      }
    }
    return {
      'name': nameController.text.trim().isEmpty ? 'Mi cuenta' : nameController.text.trim(),
      'account_type': accountType,
      'currency': currency,
      'is_active': original?['is_active'] ?? true,
      'financial_institutions': institution,
      'card_design': {
        ...cardDesign,
        'enabled': supportsDebit && cardDesign['enabled'] == true,
      },
    };
  }

  int get previewBalance {
    final amount = double.tryParse(balanceController.text.trim().replaceAll(',', '.'));
    final cents = amount == null ? null : amount * 100;
    return cents != null && cents.isFinite ? cents.round() : 0;
  }

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    if (account != null) {
      nameController.text = account['name']?.toString() ?? '';
      balanceController.text = '${account['opening_balance'] ?? 0}';
      referenceController.text = account['account_reference']?.toString() ?? '';
      notesController.text = account['notes']?.toString() ?? '';
      accountType = account['account_type'].toString();
      currency = account['currency'].toString();
      institutionId = account['institution_id']?.toString();
      final design = account['card_design'];
      if (design is Map) cardDesign = Map<String, dynamic>.from(design);
    }
    loadInstitutions();
  }

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    referenceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> loadInstitutions() async {
    setState(() { loadingInstitutions = true; institutionError = null; });
    try {
      final result = await supabase.from('financial_institutions')
          .select('id, name').eq('is_active', true).order('name');
      final rows = List<Map<String, dynamic>>.from(result);
      if (institutionId != null &&
          !rows.any((row) => row['id'].toString() == institutionId)) {
        final current = widget.account?['financial_institutions'];
        rows.add({
          'id': institutionId,
          'name': current is Map ? current['name'] ?? 'Institución actual'
              : 'Institución actual',
        });
      }
      if (!mounted) return;
      setState(() { institutions = rows; loadingInstitutions = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { institutionError = e.toString(); loadingInstitutions = false; });
    }
  }

  void save() {
    if (!canSave || !formKey.currentState!.validate()) { return; }
    final data = <String, dynamic>{
      'name': nameController.text.trim(),
      'institution_id': institutionId,
      'opening_balance': double.parse(balanceController.text.trim().replaceAll(',', '.')),
      'account_reference': referenceController.text.trim().isEmpty
          ? null : referenceController.text.trim(),
      'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      'card_design': {
        ...cardDesign,
        'enabled': supportsDebit && cardDesign['enabled'] == true,
      },
    };
    if (!editing) {
      data.addAll({'account_type': accountType, 'currency': currency});
    }
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(editing ? 'Editar cuenta' : 'Nueva cuenta'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountCard(
              account: preview, balanceCents: previewBalance,
              balanceLabel: 'Saldo inicial',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nombre de la cuenta *'),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Escribe un nombre para la cuenta' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: accountType, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de cuenta'),
              items: types.entries.map((e) => DropdownMenuItem(
                  value: e.key, child: Text(e.value))).toList(),
              onChanged: editing ? null : (value) {
                if (value == null) return;
                setState(() {
                  accountType = value;
                  if (!supportsDebit) {
                    institutionId = null;
                    cardDesign = {...cardDesign, 'enabled': false};
                  }
                });
              },
            ),
            if (requiresInstitution || institutionId != null) ...[
              const SizedBox(height: 12),
              if (loadingInstitutions) const LinearProgressIndicator()
              else if (institutionError != null) ...[
                const Text('No se pudieron cargar los bancos.'),
                TextButton(onPressed: loadInstitutions,
                    child: const Text('Reintentar')),
              ] else DropdownButtonFormField<String>(
                initialValue: institutionId ?? 'none', isExpanded: true,
                decoration: const InputDecoration(labelText: 'Banco o institución'),
                items: [
                  const DropdownMenuItem(value: 'none', child: Text('Sin institución')),
                  ...institutions.map((bank) => DropdownMenuItem(
                      value: bank['id'].toString(),
                      child: Text(bank['name'].toString(),
                          overflow: TextOverflow.ellipsis))),
                ],
                validator: (value) => supportsDebit && cardDesign['enabled'] == true &&
                    (value == null || value == 'none')
                    ? 'Selecciona el banco de la tarjeta de débito' : null,
                onChanged: (value) => setState(() {
                  institutionId = value == 'none' ? null : value;
                }),
              ),
            ],
            const SizedBox(height: 12),
            if (supportsDebit)
              AccountDesignFields(
                value: cardDesign,
                onChanged: (value) => setState(() => cardDesign = value),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: debitDesignLabels.containsKey(cardDesign['style'])
                    ? cardDesign['style'] as String : 'classic',
                decoration: const InputDecoration(labelText: 'Diseño visual'),
                items: debitDesignLabels.entries.map((e) => DropdownMenuItem(
                    value: e.key, child: Text(e.value))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => cardDesign = {...cardDesign, 'style': value});
                  }
                },
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: currency,
              decoration: const InputDecoration(labelText: 'Moneda'),
              items: const [
                DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
                DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)')),
              ],
              onChanged: editing ? null : (value) {
                if (value != null) setState(() => currency = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: balanceController,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Saldo inicial',
                helperText: 'Saldo base de la cuenta, antes de los movimientos registrados.',
                helperMaxLines: 2,
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                final amount = double.tryParse(text.replaceAll(',', '.'));
                if (amount == null || !amount.isFinite || amount < 0) {
                  return 'Introduce un saldo válido';
                }
                if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) {
                  return 'Usa máximo dos decimales, sin separadores de miles';
                }
                return null;
              },
            ),
            if (editing) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('El tipo y la moneda se conservan al editar.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Número o referencia (opcional)',
                helperText: 'No ingreses el PIN ni la contraseña bancaria.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notesController, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
          ],
        ),
      )),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: canSave ? save : null, child: const Text('Guardar')),
    ],
  );
}