import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_theme.dart';
import '../../core/supabase_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isRegister = false;
  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => loading = true);

    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (isRegister) {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (!mounted) return;

        if (response.session == null) {
          showMessage(
            'Registro enviado. Revisa tu correo para confirmar la cuenta.',
          );
        } else {
          showMessage('¡Cuenta creada correctamente!');
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      if (mounted) showMessage(e.message);
    } catch (e) {
      if (mounted) showMessage('Ocurrió un error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 64,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Mis Finanzas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isRegister
                            ? 'Crea tu cuenta personal'
                            : 'Ingresa para controlar tu dinero',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = (value ?? '').trim();

                          if (email.isEmpty) {
                            return 'Escribe tu correo electrónico';
                          }

                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(email)) {
                            return 'Escribe un correo válido';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        autofillHints: [
                          isRegister
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';

                          if (password.length < 6) {
                            return 'Usa al menos 6 caracteres';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: loading ? null : submit,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            loading
                                ? 'Procesando...'
                                : isRegister
                                ? 'Crear cuenta'
                                : 'Iniciar sesión',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                          setState(() {
                            isRegister = !isRegister;
                          });
                        },
                        child: Text(
                          isRegister
                              ? 'Ya tengo una cuenta. Iniciar sesión'
                              : 'No tengo cuenta. Registrarme',
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
    );
  }
}
