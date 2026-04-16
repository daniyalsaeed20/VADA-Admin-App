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
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: BrandTheme.vadaRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(loc.tr('dashboard.manageFightersHint'))),
                  FilledButton(
                    onPressed: () => context.go('/fighters'),
                    child: Text(loc.tr('dashboard.goToFighters')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          fightersAsync.when(
            loading: () => Center(child: Text(loc.tr('common.loading'))),
            error: (_, _) => Center(child: Text(loc.tr('fighters.error'))),
            data: (fighters) {
              final total = fighters.length;
              final active = fighters.where((it) => !it.disabled).length;
              final disabled = fighters.where((it) => it.disabled).length;
              final recent = [...fighters]..sort((a, b) {
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title: loc.tr('dashboard.totalFighters'),
                        value: total.toString(),
                        icon: Icons.groups_2_outlined,
                      ),
                      _StatCard(
                        title: loc.tr('dashboard.activeFighters'),
                        value: active.toString(),
                        icon: Icons.verified_user_outlined,
                      ),
                      _StatCard(
                        title: loc.tr('dashboard.disabledFighters'),
                        value: disabled.toString(),
                        icon: Icons.block_outlined,
                      ),
                    ],
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
                      child: recent.isEmpty
                          ? Text(loc.tr('dashboard.noRecentFighters'))
                          : Column(
                              children: recent.take(5).map((fighter) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        fighter.disabled
                                            ? Colors.grey.shade300
                                            : BrandTheme.vadaRed.withValues(
                                              alpha: 0.12,
                                            ),
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
              );
            },
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
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
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
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
