import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
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
            colors: [AppColors.loginGradientStart, AppColors.loginGradientEnd],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: EdgeInsets.all(AppLayout.cardPadding(context)),
              child: Padding(
                padding: EdgeInsets.all(AppLayout.largeGap(context)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LoginBrandHeader(),
                      SizedBox(height: AppLayout.mediumGap(context)),
                      Text(
                        loc.tr('auth.loginTitle'),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppLayout.largeGap(context)),
                      TextFormField(
                        controller: _emailController,
                        decoration:
                            InputDecoration(labelText: loc.tr('auth.email')),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.tr('fighters.required');
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppLayout.mediumGap(context)),
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
                        SizedBox(height: AppLayout.mediumGap(context)),
                        Text(
                          loc.tr(loginState.errorMessage!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      SizedBox(height: AppLayout.mediumGap(context)),
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
                                  context.go(AppRoutes.dashboard);
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
    return SizedBox(
      height: AppLayout.largeGap(context) * 3.2,
      child: const Image(
        image: AssetImage(AppAssets.vadaLogo),
        fit: BoxFit.contain,
      ),
    );
  }
}
