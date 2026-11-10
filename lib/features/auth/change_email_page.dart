import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final userId = supabase.auth.currentUser?.id;
  User? user = supabase.auth.currentUser;
  String? requestedEmail;
  String? message;
  String? error;
  bool busy = false;

  String? get pendingEmail {
    final pending = user?.newEmail?.trim();
    return pending == null || pending.isEmpty ? requestedEmail : pending;
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !formKey.currentState!.validate()) return;
    final newEmail = email.text.trim();
    FocusScope.of(context).unfocus();
    await run(() async {
      final response = await supabase.auth.updateUser(
        UserAttributes(email: newEmail),
      );
      final updated = response.user;
      if (!mounted || !checkSession(updated)) return;
      final confirmed = updated?.email?.toLowerCase() == newEmail.toLowerCase();
      email.clear();
      setState(() {
        user = updated;
        requestedEmail = confirmed ? null : newEmail;
        message = confirmed
            ? 'Correo de acceso actualizado.'
            : 'Solicitud enviada. Revisa el correo actual y el nuevo para completar la confirmación.';
      });
    });
  }

  Future<void> refresh() => run(() async {
    final response = await supabase.auth.refreshSession();
    final updated = response.user;
    if (!mounted || !checkSession(updated)) return;
    final confirmed =
        updated?.email?.toLowerCase() == pendingEmail?.toLowerCase();
    setState(() {
      user = updated;
      if (confirmed) requestedEmail = null;
      message = confirmed
          ? 'Correo de acceso actualizado.'
          : 'La confirmación sigue pendiente. Revisa los enlaces recibidos.';
    });
  });

  bool checkSession(User? current) {
    if (userId != null &&
        supabase.auth.currentUser?.id == userId &&
        current?.id == userId) {
      return true;
    }
    setState(() => error = 'La sesión cambió. Vuelve a abrir esta pantalla.');
    return false;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy || !checkSession(supabase.auth.currentUser)) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) {
        setState(
          () => error = 'No se pudo completar la solicitud. ${e.message}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'No se pudo completar la solicitud. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = pendingEmail;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Correo electrónico')),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Correo de acceso actual'),
                          SelectableText(
                            user?.email ?? 'Sin correo registrado',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Este es el correo que usas para iniciar sesión. Tu nombre de perfil se edita por separado.',
                          ),
                          if (pending != null) ...[
                            const SizedBox(height: 16),
                            Text('Correo pendiente de confirmación: $pending'),
                            const Text(
                              'Sigue usando el correo actual hasta que se confirme el cambio.',
                            ),
                            TextButton(
                              onPressed: busy ? null : refresh,
                              child: const Text('Verificar confirmación'),
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: email,
                            enabled: !busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => save(),
                            decoration: const InputDecoration(
                              labelText: 'Nuevo correo electrónico',
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(text)) {
                                return 'Escribe un correo válido.';
                              }
                              if (text.toLowerCase() ==
                                  user?.email?.toLowerCase()) {
                                return 'Escribe un correo distinto del actual.';
                              }
                              return null;
                            },
                          ),
                          if (message != null) ...[
                            const SizedBox(height: 12),
                            Text(message!),
                          ],
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: busy ? null : save,
                            child: Text(
                              busy ? 'Procesando…' : 'Solicitar cambio',
                            ),
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
}
