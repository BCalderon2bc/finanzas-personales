import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/exchange_rate.dart';
import '../../data/financial_settings_repository.dart';
import '../auth/change_password_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  String? ownerId, error;
  bool loading = true, saving = false;
  FinancialSettings? current;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    final userId = supabase.auth.currentUser?.id;
    try {
      final result = await loadFinancialSettings();
      if (!mounted) { return; }
      if (supabase.auth.currentUser?.id != userId) {
        throw StateError('La sesión cambió. Abre nuevamente Configuraciones.');
      }
      setState(() {
        ownerId = userId;
        current = result;
        controller.text = result?.rate.decimal ?? '';
        loading = false;
      });
    } catch (e) {
      if (mounted) { setState(() { loading = false; error = '$e'; }); }
    }
  }

  Future<void> save() async {
    if (loading || saving || ownerId == null || !formKey.currentState!.validate()) {
      return;
    }
    final rate = ExchangeRate.tryParse(controller.text)!;
    FocusScope.of(context).unfocus();
    setState(() => saving = true);
    try {
      await saveFinancialSettings(rate, ownerId!);
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasa guardada. El inicio recalculará los totales.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) { setState(() => saving = false); }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Configuraciones')),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: loading ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
            if (error != null) ...[
              const Text('No se pudo cargar la configuración.'),
              SelectableText(error!),
              TextButton(onPressed: load, child: const Text('Reintentar')),
            ] else Card(child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(key: formKey, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.currency_exchange_rounded,
                    color: Color(0xFF2563EB), size: 36),
                  const SizedBox(height: 14),
                  Text('Tasa de cambio', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Indica cuántos córdobas equivalen a un dólar. '
                    'La tasa se guarda en tu cuenta y se utiliza para presentar '
                    'los totales equivalentes del inicio.'),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: controller,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Córdobas por dólar',
                      prefixText: '1 USD = ', suffixText: 'C\$',
                      hintText: 'Ej. 36.62', border: OutlineInputBorder(),
                      helperText: 'Tasa manual. Hasta 6 decimales, sin separadores de miles.',
                      helperMaxLines: 2,
                    ),
                    validator: (value) => ExchangeRate.tryParse(value ?? '') == null
                      ? 'Escribe una tasa mayor que 0 y hasta 1,000,000; máximo 6 decimales.'
                      : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (ExchangeRate.tryParse(controller.text) case final rate?)
                    Text('US\$ 1.00 = C\$ ${rate.decimal}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  const Text('No cambia las monedas ni los importes de tus cuentas, '
                    'tarjetas o movimientos. Tampoco registra ganancias o pérdidas cambiarias. '
                    'Se aplica la misma tasa al mes seleccionado y al mes anterior.',
                    style: TextStyle(color: Color(0xFF64748B), height: 1.5)),
                  if (current?.updatedAt case final date?) ...[
                    const SizedBox(height: 12),
                    Text('Última actualización: ${date.day}/${date.month}/${date.year}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Guardando...' : 'Guardar tasa'),
                  ),
                ],
              )),
            )),
            const SizedBox(height: 16),
            Card(child: ListTile(
              enabled: !saving,
              leading: const Icon(Icons.lock_reset_rounded),
              title: const Text('Cambiar contraseña'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: saving ? null : () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const ChangePasswordPage())),
            )),
          ]),
      )),
    ),
  );
}
