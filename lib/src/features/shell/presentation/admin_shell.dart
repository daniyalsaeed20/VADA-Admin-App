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
    final navItems = [
      _NavItem(
        route: '/dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: loc.tr('nav.dashboard'),
      ),
      _NavItem(
        route: '/fighters',
        icon: Icons.sports_mma_outlined,
        selectedIcon: Icons.sports_mma,
        label: loc.tr('nav.fighters'),
      ),
      _NavItem(
        route: '/contacts',
        icon: Icons.contact_phone_outlined,
        selectedIcon: Icons.contact_phone,
        label: loc.tr('nav.contacts'),
      ),
      _NavItem(
        route: '/locations',
        icon: Icons.location_on_outlined,
        selectedIcon: Icons.location_on,
        label: loc.tr('nav.locations'),
      ),
      _NavItem(
        route: '/whereabouts',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: loc.tr('nav.whereabouts'),
      ),
      _NavItem(
        route: '/checkins',
        icon: Icons.gps_fixed_outlined,
        selectedIcon: Icons.gps_fixed,
        label: loc.tr('nav.checkins'),
      ),
      _NavItem(
        route: '/notifications',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: loc.tr('nav.notifications'),
      ),
      _NavItem(
        route: '/reports',
        icon: Icons.assessment_outlined,
        selectedIcon: Icons.assessment,
        label: loc.tr('nav.reports'),
      ),
      _NavItem(
        route: '/settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: loc.tr('nav.settings'),
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final selectedIndex = _selectedIndex(currentPath, navItems);
    final useCompactLayout = width < 900;
    final useExtendedRail = width >= 1280;

    if (useCompactLayout) {
      return Scaffold(
        appBar: AppBar(
          title: const _RailBrandHeader(isCompact: true),
          actions: [
            _LocaleMenuButton(
              locale: locale,
              onSelected: (newLocale) {
                ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(newLocale);
              },
            ),
            IconButton(
              tooltip: loc.tr('auth.signOut'),
              onPressed: () async {
                await ref.read(authRepositoryProvider).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _RailBrandHeader(),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      return ListTile(
                        leading: Icon(
                          selectedIndex == index
                              ? item.selectedIcon
                              : item.icon,
                        ),
                        title: Text(item.label),
                        selected: selectedIndex == index,
                        onTap: () {
                          Navigator.of(context).pop();
                          if (currentPath != item.route) {
                            context.go(item.route);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            leading: Padding(
              padding: EdgeInsets.fromLTRB(
                useExtendedRail ? 12 : 8,
                12,
                useExtendedRail ? 12 : 8,
                8,
              ),
              child: _RailBrandHeader(isCompact: !useExtendedRail),
            ),
            extended: useExtendedRail,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              context.go(navItems[index].route);
            },
            labelType: useExtendedRail
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            destinations: navItems
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
            trailing: _RailTrailingControls(
              locale: locale,
              isExtended: useExtendedRail,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(
    String currentPath,
    List<_NavItem> navItems,
  ) {
    for (var i = 0; i < navItems.length; i++) {
      if (currentPath.startsWith(navItems[i].route)) {
        return i;
      }
    }
    return 0;
  }
}

class _RailBrandHeader extends StatelessWidget {
  const _RailBrandHeader({this.isCompact = false});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'VADA',
          style: TextStyle(
            color: BrandTheme.vadaRed,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: 0.8,
            height: 1,
          ),
        ),
        if (!isCompact) const SizedBox(height: 2),
        if (!isCompact)
          const Text(
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

class _RailTrailingControls extends ConsumerWidget {
  const _RailTrailingControls({
    required this.locale,
    required this.isExtended,
  });

  final Locale locale;
  final bool isExtended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.l10n;

    if (!isExtended) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocaleMenuButton(
            locale: locale,
            onSelected: (newLocale) {
              ref.read(localeControllerProvider.notifier).setLocale(newLocale);
            },
          ),
          IconButton(
            tooltip: loc.tr('auth.signOut'),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return SizedBox(
      width: 178,
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
    );
  }
}

class _LocaleMenuButton extends StatelessWidget {
  const _LocaleMenuButton({required this.locale, required this.onSelected});

  final Locale locale;
  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    return PopupMenuButton<Locale>(
      tooltip: loc.tr('nav.language'),
      initialValue: locale,
      onSelected: onSelected,
      itemBuilder: (_) {
        return AppLocalizations.supportedLocales
            .map(
              (item) => PopupMenuItem(
                value: item,
                child: Text(item.languageCode.toUpperCase()),
              ),
            )
            .toList();
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.language),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
