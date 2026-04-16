import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/brand_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../bootstrap/bootstrap_service.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bootstrapCollectionsProvider);
    final currentPath = GoRouterState.of(context).matchedLocation;
    final locale = ref.watch(localeControllerProvider);
    final loc = context.l10n;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            leading: const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _RailBrandHeader(),
            ),
            selectedIndex: _selectedIndex(currentPath),
            onDestinationSelected: (index) {
              if (index == 0) {
                context.go('/dashboard');
              } else {
                context.go('/fighters');
              }
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: Text(loc.tr('nav.dashboard')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.sports_mma_outlined),
                selectedIcon: const Icon(Icons.sports_mma),
                label: Text(loc.tr('nav.fighters')),
              ),
            ],
            trailing: SizedBox(
              width: 132,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Locale>(
                      initialValue: locale,
                      decoration: InputDecoration(
                        labelText: loc.tr('nav.language'),
                        border: const OutlineInputBorder(),
                      ),
                      items: AppLocalizations.supportedLocales
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.languageCode.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (newLocale) {
                        if (newLocale != null) {
                          ref
                              .read(localeControllerProvider.notifier)
                              .setLocale(newLocale);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(loc.tr('auth.signOut')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String currentPath) {
    if (currentPath.startsWith('/fighters')) {
      return 1;
    }
    return 0;
  }
}

class _RailBrandHeader extends StatelessWidget {
  const _RailBrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'VADA',
          style: TextStyle(
            color: BrandTheme.vadaRed,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: 0.8,
            height: 1,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Admin',
          style: TextStyle(
            color: BrandTheme.vadaCharcoal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
