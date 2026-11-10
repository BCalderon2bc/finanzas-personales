import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../widgets/app_version_footer.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loginForm = Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/branding/mi_billete.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    semanticLabel: 'Mi Billete',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mi Billete',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isRegister
                    ? 'Crea tu cuenta personal'
                    : 'Ingresa con el correo de tu cuenta',
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
                  hintText: 'nombre@ejemplo.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = (value ?? '').trim();

                  if (email.isEmpty) {
                    return 'Escribe tu correo electrónico';
                  }

                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Usa el correo de tu cuenta, como nombre@ejemplo.com';
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
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
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

              const AppVersionFooter(),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 820) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: loginForm,
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: colors.onPrimary),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 36,
                                  color: colors.onPrimary,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Tu dinero en un solo lugar',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: colors.onPrimary),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Consulta tus saldos, organiza tus movimientos y ten a mano tus próximos pagos.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(child: loginForm),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
