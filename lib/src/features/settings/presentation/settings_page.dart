import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_layout.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.l10n;
    final locale = ref.watch(localeControllerProvider);
    final auth = ref.watch(firebaseAuthProvider);
    final user = auth.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppLayout.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.tr('nav.settings'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: AppLayout.sectionGap(context)),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.tr('settings.language'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      DropdownButtonFormField<Locale>(
                        initialValue: locale,
                        decoration: InputDecoration(
                          labelText: loc.tr('nav.language'),
                          border: const OutlineInputBorder(),
                        ),
                        items: AppLocalizations.supportedLocales
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(l.languageCode.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (next) {
                          if (next != null) {
                            ref.read(localeControllerProvider.notifier).setLocale(next);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppLayout.mediumGap(context)),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.tr('settings.adminProfile'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: Text(user?.email ?? '—'),
                        subtitle: Text('UID: ${user?.uid ?? '—'}'),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await ref.read(authRepositoryProvider).logout();
                            if (context.mounted) context.go(AppRoutes.login);
                          },
                          icon: const Icon(Icons.logout),
                          label: Text(loc.tr('auth.signOut')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppLayout.mediumGap(context)),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.tr('settings.appInfo'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline),
                        title: const Text('VADA Admin'),
                        subtitle: Text(loc.tr('settings.appInfoSubtitle')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

