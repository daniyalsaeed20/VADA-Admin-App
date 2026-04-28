import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_layout.dart';
import '../../auth/presentation/auth_controller.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final locale = ref.watch(localeControllerProvider);
    final loc = context.l10n;
    final navItems = [
      _NavItem(
        route: AppRoutes.dashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: loc.tr('nav.dashboard'),
      ),
      _NavItem(
        route: AppRoutes.fighters,
        icon: Icons.sports_mma_outlined,
        selectedIcon: Icons.sports_mma,
        label: loc.tr('nav.fighters'),
      ),
      _NavItem(
        route: AppRoutes.contacts,
        icon: Icons.contact_phone_outlined,
        selectedIcon: Icons.contact_phone,
        label: loc.tr('nav.contacts'),
      ),
      _NavItem(
        route: AppRoutes.locations,
        icon: Icons.location_on_outlined,
        selectedIcon: Icons.location_on,
        label: loc.tr('nav.locations'),
      ),
      _NavItem(
        route: AppRoutes.whereabouts,
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: loc.tr('nav.whereabouts'),
      ),
      _NavItem(
        route: AppRoutes.checkins,
        icon: Icons.gps_fixed_outlined,
        selectedIcon: Icons.gps_fixed,
        label: loc.tr('nav.checkins'),
      ),
      _NavItem(
        route: AppRoutes.notifications,
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: loc.tr('nav.notifications'),
      ),
      _NavItem(
        route: AppRoutes.reports,
        icon: Icons.assessment_outlined,
        selectedIcon: Icons.assessment,
        label: loc.tr('nav.reports'),
      ),
      _NavItem(
        route: AppRoutes.settings,
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
              useProminentStyle: true,
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
                  context.go(AppRoutes.login);
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
    final logoHeight = isCompact
        ? AppLayout.largeGap(context) * 1.5
        : AppLayout.largeGap(context) * 2.3;
    return SizedBox(
      height: logoHeight,
      child: const Image(
        image: AssetImage(AppAssets.vadaLogo),
        fit: BoxFit.contain,
      ),
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
                context.go(AppRoutes.login);
              }
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return SizedBox(
      width: AppLayout.kpiCardWidth(context) * 0.78,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.mediumGap(context)),
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
            SizedBox(height: AppLayout.mediumGap(context)),
            FilledButton.icon(
              onPressed: () async {
                await ref.read(authRepositoryProvider).logout();
                if (context.mounted) {
                  context.go(AppRoutes.login);
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
  const _LocaleMenuButton({
    required this.locale,
    required this.onSelected,
    this.useProminentStyle = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onSelected;
  final bool useProminentStyle;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: useProminentStyle ? 12 : 8,
            vertical: useProminentStyle ? 6 : 4,
          ),
          decoration: BoxDecoration(
            color: useProminentStyle
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: useProminentStyle
                  ? colorScheme.primary.withValues(alpha: 0.55)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.translate_rounded,
                size: useProminentStyle ? 18 : 16,
                color: useProminentStyle
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                locale.languageCode.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: useProminentStyle
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              if (useProminentStyle) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ],
            ],
          ),
        ),
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
