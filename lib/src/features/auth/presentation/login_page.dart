import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/brand_theme.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final loginState = ref.watch(loginFormControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6F6F6), Color(0xFFECECEC)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LoginBrandHeader(),
                      const SizedBox(height: 16),
                      Text(
                        loc.tr('auth.loginTitle'),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(labelText: loc.tr('auth.email')),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.tr('fighters.required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: loc.tr('auth.password'),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.tr('fighters.required');
                          }
                          return null;
                        },
                      ),
                      if (loginState.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          loc.tr(loginState.errorMessage!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: loginState.isLoading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }
                                final success = await ref
                                    .read(loginFormControllerProvider.notifier)
                                    .login(
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    );
                                if (success && context.mounted) {
                                  context.go('/dashboard');
                                }
                              },
                        child: Text(
                          loginState.isLoading
                              ? loc.tr('auth.loggingIn')
                              : loc.tr('auth.login'),
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

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text(
          'VADA',
          style: TextStyle(
            color: BrandTheme.vadaRed,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            height: 1,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Voluntary Anti-Doping Association',
          style: TextStyle(
            color: BrandTheme.vadaCharcoal,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
