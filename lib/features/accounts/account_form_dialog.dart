import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';

class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({super.key});

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final balanceController = TextEditingController(text: '0.00');
  final referenceController = TextEditingController();
  final notesController = TextEditingController();

  String accountType = 'savings';
  String currency = 'NIO';
  String? institutionId;

  List<Map<String, dynamic>> institutions = [];
  bool loadingInstitutions = true;
  String? institutionError;

  @override
  void initState() {
    super.initState();
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
    try {
      final result = await supabase
          .from('financial_institutions')
          .select('id, name, code, institution_type')
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;

      setState(() {
        institutions = List<Map<String, dynamic>>.from(result);
        loadingInstitutions = false;
        institutionError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingInstitutions = false;
        institutionError = e.toString();
      });
    }
  }

  String institutionLabel(Map<String, dynamic> institution) {
    return institution['name']?.toString() ?? 'Institución';
  }

  bool get requiresInstitution {
    return accountType == 'savings' || accountType == 'checking';
  }

  void save() {
    if (!formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      balanceController.text.trim().replaceAll(',', '.'),
    );

    if (amount == null || !amount.isFinite || amount < 0) {
      return;
    }

    Navigator.of(context).pop(<String, dynamic>{
      'name': nameController.text.trim(),
      'account_type': accountType,
      'currency': currency,
      'opening_balance': amount,
      'institution_id': institutionId,
      'account_reference': referenceController.text.trim().isEmpty
          ? null
          : referenceController.text.trim(),
      'notes': notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva cuenta'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la cuenta *',
                    hintText: 'Ej. Mi cuenta de ahorro',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Escribe un nombre para la cuenta';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: accountType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cuenta *',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'savings',
                      child: Text('Cuenta de ahorro'),
                    ),
                    DropdownMenuItem(
                      value: 'checking',
                      child: Text('Cuenta corriente'),
                    ),
                    DropdownMenuItem(
                      value: 'cash',
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: 'wallet',
                      child: Text('Billetera digital'),
                    ),
                    DropdownMenuItem(
                      value: 'investment',
                      child: Text('Inversión'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Otra cuenta'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      accountType = value;

                      if (!requiresInstitution) {
                        institutionId = null;
                      }
                    });
                  },
                ),
                if (requiresInstitution) ...[
                  const SizedBox(height: 16),
                  if (loadingInstitutions)
                    const LinearProgressIndicator()
                  else if (institutionError != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'No se pudieron cargar los bancos: '
                              '$institutionError',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: loadInstitutions,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ),
                      ],
                    )
                  else
                    DropdownButtonFormField<String?>(
                      value: institutionId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Banco o institución',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sin institución'),
                        ),
                        ...institutions.map((institution) {
                          return DropdownMenuItem<String?>(
                            value: institution['id'].toString(),
                            child: Text(
                              institutionLabel(institution),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => institutionId = value);
                      },
                    ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: currency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Moneda *',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'NIO',
                      child: Text('Córdobas (C\$)'),
                    ),
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('Dólares (US\$)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => currency = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Saldo inicial *',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );

                    if (amount == null ||
                        !amount.isFinite ||
                        amount < 0) {
                      return 'Introduce un saldo válido';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Número o referencia (opcional)',
                    prefixIcon: Icon(Icons.numbers),
                    helperText: 'No ingreses el PIN ni la contraseña bancaria.',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
