import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/brand_theme.dart';
import '../../fighters/presentation/fighters_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.l10n;
    final fightersAsync = ref.watch(fightersStreamProvider);
    final isNarrow = MediaQuery.sizeOf(context).width < 760;
    final fightersData = fightersAsync.asData?.value ?? const [];
    final total = fightersData.length;
    final active = fightersData.where((it) => !it.disabled).length;
    final disabled = fightersData.where((it) => it.disabled).length;
    final recent = [...fightersData]..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        if (aDate == null && bDate == null) {
          return 0;
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });

    String fighterMetricValue(int value) {
      if (fightersAsync.isLoading) {
        return loc.tr('common.loading');
      }
      if (fightersAsync.hasError) {
        return '-';
      }
      return value.toString();
    }

    final dataCards = [
      (
        title: loc.tr('dashboard.totalFighters'),
        value: fighterMetricValue(total),
        icon: Icons.groups_2_outlined,
        isSoon: false,
      ),
      (
        title: loc.tr('dashboard.activeFighters'),
        value: fighterMetricValue(active),
        icon: Icons.verified_user_outlined,
        isSoon: false,
      ),
      (
        title: loc.tr('dashboard.disabledFighters'),
        value: fighterMetricValue(disabled),
        icon: Icons.block_outlined,
        isSoon: false,
      ),
      (
        title: loc.tr('nav.contacts'),
        value: loc.tr('common.comingSoon'),
        icon: Icons.contact_phone_outlined,
        isSoon: true,
      ),
      (
        title: loc.tr('nav.locations'),
        value: loc.tr('common.comingSoon'),
        icon: Icons.location_on_outlined,
        isSoon: true,
      ),
      (
        title: loc.tr('nav.whereabouts'),
        value: loc.tr('common.comingSoon'),
        icon: Icons.calendar_month_outlined,
        isSoon: true,
      ),
      (
        title: loc.tr('nav.checkins'),
        value: loc.tr('common.comingSoon'),
        icon: Icons.gps_fixed_outlined,
        isSoon: true,
      ),
      (
        title: loc.tr('nav.notifications'),
        value: loc.tr('common.comingSoon'),
        icon: Icons.notifications_outlined,
        isSoon: true,
      ),
      (
        title: loc.tr('nav.reports'),
        value: loc.tr('common.comingSoon'),
        icon: Icons.assessment_outlined,
        isSoon: true,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('dashboard.title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(loc.tr('dashboard.subtitle')),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: BrandTheme.vadaRed,
                        ),
                        const SizedBox(height: 10),
                        Text(loc.tr('dashboard.manageFightersHint')),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context.go('/fighters'),
                          child: Text(loc.tr('dashboard.goToFighters')),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: BrandTheme.vadaRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child:
                                Text(loc.tr('dashboard.manageFightersHint'))),
                        FilledButton(
                          onPressed: () => context.go('/fighters'),
                          child: Text(loc.tr('dashboard.goToFighters')),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (fightersAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                loc.tr('fighters.error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Text(
            loc.tr('dashboard.dataOverviewTitle'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: dataCards
                .map(
                  (item) => _StatCard(
                    title: item.title,
                    value: item.value,
                    icon: item.icon,
                    isComingSoon: item.isSoon,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Text(
            loc.tr('dashboard.recentFighters'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: fightersAsync.isLoading
                  ? Text(loc.tr('common.loading'))
                  : recent.isEmpty
                      ? Text(loc.tr('dashboard.noRecentFighters'))
                      : Column(
                          children: recent.take(5).map((fighter) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: fighter.disabled
                                    ? Colors.grey.shade300
                                    : BrandTheme.vadaRed
                                        .withValues(alpha: 0.12),
                                child: Icon(
                                  fighter.disabled
                                      ? Icons.person_off
                                      : Icons.person,
                                  color: BrandTheme.vadaCharcoal,
                                ),
                              ),
                              title: Text(fighter.fullName),
                              subtitle: Text(fighter.email),
                              trailing: Chip(
                                label: Text(
                                  fighter.disabled
                                      ? loc.tr('fighters.disabled')
                                      : loc.tr('fighters.enabled'),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isComingSoon = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool isComingSoon;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 760;
    return SizedBox(
      width: isNarrow ? double.infinity : 230,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: BrandTheme.vadaRed),
              const SizedBox(height: 10),
              Text(title),
              const SizedBox(height: 8),
              Text(
                value,
                style: isComingSoon
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
