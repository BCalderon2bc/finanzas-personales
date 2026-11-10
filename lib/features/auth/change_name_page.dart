import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

Future<String?> fetchProfileName(String userId) async {
  final profile = await supabase
      .from('profiles')
      .select('full_name')
      .eq('id', userId)
      .maybeSingle();
  final name = profile?['full_name']?.toString().trim() ?? '';
  return name.isEmpty ? null : name;
}

class ChangeNamePage extends StatefulWidget {
  const ChangeNamePage({super.key});

  @override
  State<ChangeNamePage> createState() => _ChangeNamePageState();
}

class _ChangeNamePageState extends State<ChangeNamePage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final userId = supabase.auth.currentUser?.id;
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadName();
  }

  Future<void> loadName() async {
    try {
      final id = userId;
      if (id == null) return;
      final currentName = await fetchProfileName(id);
      if (mounted && supabase.auth.currentUser?.id == id) {
        name.text = currentName ?? '';
      }
    } catch (_) {
      if (mounted)
        setState(() => error = 'No se pudo cargar el nombre actual.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (loading || saving || !formKey.currentState!.validate()) return;
    if (userId == null || supabase.auth.currentUser?.id != userId) {
      setState(() => error = 'La sesión cambió. Vuelve a abrir esta pantalla.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });

    try {
      final updated = await supabase.rpc<String>(
        'update_my_profile_name',
        params: {'p_full_name': name.text.trim()},
      );
      if (!mounted) return;
      if (supabase.auth.currentUser?.id != userId) {
        setState(
          () => error = 'La sesión cambió. Vuelve a abrir esta pantalla.',
        );
        return;
      }
      Navigator.pop(context, updated);
    } on PostgrestException catch (e) {
      if (mounted)
        setState(() => error = 'No se pudo guardar el nombre. ${e.message}');
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'No se pudo guardar el nombre. Intenta nuevamente.',
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Cambiar nombre')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Elige el nombre que aparecerá en Mi Billete.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: name,
                          enabled: !loading && !saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => save(),
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Ingresa tu nombre.';
                            if (text.runes.length > 100)
                              return 'Usa hasta 100 caracteres.';
                            return null;
                          },
                        ),
                        if (error != null)
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: loading || saving ? null : save,
                          child: Text(saving ? 'Guardando…' : 'Guardar nombre'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
