import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final formKey = GlobalKey<FormState>();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmation = TextEditingController();
  bool saving = false, completed = false;
  bool hideCurrent = true, hideNew = true, hideConfirmation = true;
  String? error;

  @override
  void dispose() {
    currentPassword.dispose();
    newPassword.dispose();
    confirmation.dispose();
    super.dispose();
  }

  String authError(AuthException exception) {
    final message = exception.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return 'La contraseña actual no es correcta.';
    }
    if (message.contains('same_password') ||
        message.contains('different from the old') ||
        message.contains('different from the previous')) {
      return 'La nueva contraseña debe ser diferente de la actual.';
    }
    if (message.contains('rate limit') || message.contains('too many requests')) {
      return 'Hay demasiados intentos. Espera un momento y vuelve a intentarlo.';
    }
    if (message.contains('reauthentication') || message.contains('session') ||
        message.contains('jwt')) {
      return 'Debes volver a iniciar sesión antes de cambiar tu contraseña.';
    }
    if (message.contains('password')) {
      return 'La contraseña no cumple los requisitos de la cuenta. '
          'Prueba una más larga que combine letras, números y símbolos.';
    }
    return 'No se pudo cambiar la contraseña. Comprueba tu conexión e intenta nuevamente.';
  }

  Future<void> save() async {
    if (saving || completed || !formKey.currentState!.validate()) {
      return;
    }
    final user = supabase.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      setState(() => error = 'Inicia sesión con tu correo para cambiar la contraseña.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { saving = true; error = null; });
    var verifyingCurrent = true;
    try {
      final verified = await supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword.text,
      );
      if (!mounted) { return; }
      if (verified.user?.id != user.id || supabase.auth.currentUser?.id != user.id) {
        setState(() => error = 'La sesión cambió. Abre nuevamente esta pantalla.');
        return;
      }
      verifyingCurrent = false;
      final result = await supabase.auth.updateUser(
        UserAttributes(password: newPassword.text),
      );
      if (!mounted) { return; }
      if (result.user?.id != user.id) {
        setState(() => error = 'No se pudo confirmar el cambio. Inicia sesión nuevamente.');
        return;
      }
      currentPassword.clear();
      newPassword.clear();
      confirmation.clear();
      setState(() => completed = true);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => error = verifyingCurrent &&
            e.message.toLowerCase().contains('invalid login credentials')
            ? 'La contraseña actual no es correcta.' : authError(e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo completar el cambio. Comprueba tu conexión e intenta nuevamente.');
      }
    } finally {
      if (mounted) { setState(() => saving = false); }
    }
  }

  Widget passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback toggle,
    required String? Function(String?) validator,
    bool last = false,
    bool isCurrent = false,
  }) => TextFormField(
    controller: controller,
    enabled: !saving,
    obscureText: hidden,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [isCurrent ? AutofillHints.password : AutofillHints.newPassword],
    textInputAction: last ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: last ? (_) { save(); } : null,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        tooltip: hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
        onPressed: saving ? null : toggle,
        icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB), green = Color(0xFF087F5B), muted = Color(0xFF64748B);
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Cambiar contraseña')),
        body: SafeArea(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(margin: EdgeInsets.zero,
              child: Padding(padding: const EdgeInsets.all(24),
                child: completed
                  ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Icon(Icons.check_circle_outline_rounded, color: green, size: 58),
                      const SizedBox(height: 18),
                      const Text('Contraseña actualizada', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      const Text('Usa tu nueva contraseña la próxima vez que inicies sesión.',
                        textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.5)),
                      const SizedBox(height: 24),
                      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Volver al inicio')),
                    ])
                  : AutofillGroup(child: Form(key: formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Icon(Icons.lock_reset_rounded, color: blue, size: 48),
                      const SizedBox(height: 16),
                      const Text('Actualiza tu contraseña', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(supabase.auth.currentUser?.email ?? '', style: const TextStyle(color: muted)),
                      const SizedBox(height: 8),
                      const Text('Ingresa tu contraseña actual y confirma la nueva. Usa al menos 8 caracteres.',
                        style: TextStyle(color: muted, height: 1.5)),
                      const SizedBox(height: 24),
                      passwordField(controller: currentPassword, label: 'Contraseña actual',
                        hidden: hideCurrent, isCurrent: true,
                        toggle: () => setState(() => hideCurrent = !hideCurrent),
                        validator: (v) => (v ?? '').isEmpty ? 'Ingresa tu contraseña actual' : null),
                      const SizedBox(height: 16),
                      passwordField(controller: newPassword, label: 'Nueva contraseña', hidden: hideNew,
                        toggle: () => setState(() => hideNew = !hideNew),
                        validator: (v) {
                          if ((v ?? '').length < 8) { return 'Usa al menos 8 caracteres'; }
                          if (v == currentPassword.text) { return 'Debe ser diferente de la contraseña actual'; }
                          return null;
                        }),
                      const SizedBox(height: 16),
                      passwordField(controller: confirmation, label: 'Confirmar nueva contraseña',
                        hidden: hideConfirmation, last: true,
                        toggle: () => setState(() => hideConfirmation = !hideConfirmation),
                        validator: (v) => (v ?? '').isEmpty || v != newPassword.text ? 'Las contraseñas deben coincidir' : null),
                      if (error != null) Padding(padding: const EdgeInsets.only(top: 16),
                        child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.4))),
                      const SizedBox(height: 24),
                      FilledButton.icon(onPressed: saving ? null : save,
                        icon: saving ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                        label: Text(saving ? 'Guardando...' : 'Guardar contraseña')),
                    ]))),
              )),
          ),
        ))),
      ),
    );
  }
}
