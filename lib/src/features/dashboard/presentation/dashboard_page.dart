import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/brand_theme.dart';
import '../../fighters/domain/fighter.dart';
import '../../fighters/presentation/fighters_controller.dart';

final collectionCountProvider = StreamProvider.family<int, String>((ref, name) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection(name).snapshots().map((snapshot) {
    return snapshot.docs
        .where((doc) => doc.id != FirestoreCollections.metaDoc)
        .length;
  });
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.l10n;
    final fightersAsync = ref.watch(fightersStreamProvider);
    final contactsAsync =
        ref.watch(collectionCountProvider(FirestoreCollections.contacts));
    final locationsAsync =
        ref.watch(collectionCountProvider(FirestoreCollections.locations));
    final schedulesAsync =
        ref.watch(collectionCountProvider(FirestoreCollections.schedules));
    final checkinsAsync =
        ref.watch(collectionCountProvider(FirestoreCollections.checkins));
    final notificationsAsync =
        ref.watch(collectionCountProvider(FirestoreCollections.notifications));
    final scheduleRequestsAsync = ref.watch(
      collectionCountProvider(FirestoreCollections.scheduleRequests),
    );

    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 760;
    final fightersData = fightersAsync.asData?.value ?? const <Fighter>[];
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

    String valueForCount(AsyncValue<int> count) {
      if (count.isLoading) {
        return loc.tr('common.loading');
      }
      if (count.hasError) {
        return '0';
      }
      return '${count.asData?.value ?? 0}';
    }

    final kpiItems = [
      _KpiItem(
        title: loc.tr('dashboard.totalFighters'),
        value: fightersAsync.isLoading
            ? loc.tr('common.loading')
            : fightersAsync.hasError
                ? '0'
                : '$total',
        icon: Icons.groups_2_outlined,
      ),
      _KpiItem(
        title: loc.tr('nav.contacts'),
        value: valueForCount(contactsAsync),
        icon: Icons.contact_phone_outlined,
      ),
      _KpiItem(
        title: loc.tr('nav.locations'),
        value: valueForCount(locationsAsync),
        icon: Icons.location_on_outlined,
      ),
      _KpiItem(
        title: loc.tr('dashboard.schedules'),
        value: valueForCount(schedulesAsync),
        icon: Icons.calendar_month_outlined,
      ),
      _KpiItem(
        title: loc.tr('nav.checkins'),
        value: valueForCount(checkinsAsync),
        icon: Icons.gps_fixed_outlined,
      ),
      _KpiItem(
        title: loc.tr('nav.notifications'),
        value: valueForCount(notificationsAsync),
        icon: Icons.notifications_outlined,
      ),
      _KpiItem(
        title: loc.tr('dashboard.scheduleRequests'),
        value: valueForCount(scheduleRequestsAsync),
        icon: Icons.swap_horiz_outlined,
      ),
    ];

    final chartValues = {
      loc.tr('nav.fighters'): total,
      loc.tr('nav.contacts'): contactsAsync.asData?.value ?? 0,
      loc.tr('nav.locations'): locationsAsync.asData?.value ?? 0,
      loc.tr('dashboard.schedules'): schedulesAsync.asData?.value ?? 0,
      loc.tr('nav.checkins'): checkinsAsync.asData?.value ?? 0,
      loc.tr('nav.notifications'): notificationsAsync.asData?.value ?? 0,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppLayout.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    BrandTheme.vadaRed.withValues(alpha: 0.95),
                    BrandTheme.vadaRedDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.all(AppLayout.largeGap(context)),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.tr('dashboard.heroTitle'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        SizedBox(height: AppLayout.smallGap(context)),
                        Text(
                          loc.tr('dashboard.heroSubtitle'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        SizedBox(height: AppLayout.mediumGap(context)),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: BrandTheme.vadaRedDark,
                          ),
                          onPressed: () => context.go(AppRoutes.fighters),
                          icon: const Icon(Icons.sports_mma_outlined),
                          label: Text(loc.tr('dashboard.goToFighters')),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.tr('dashboard.heroTitle'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                              SizedBox(height: AppLayout.smallGap(context)),
                              Text(
                                loc.tr('dashboard.heroSubtitle'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppLayout.mediumGap(context)),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: BrandTheme.vadaRedDark,
                          ),
                          onPressed: () => context.go(AppRoutes.fighters),
                          icon: const Icon(Icons.sports_mma_outlined),
                          label: Text(loc.tr('dashboard.goToFighters')),
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(height: AppLayout.mediumGap(context)),
          Text(
            loc.tr('dashboard.keyOperations'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kpiItems.map((item) => _KpiCard(item: item)).toList(),
          ),
          SizedBox(height: AppLayout.sectionGap(context)),
          Text(
            loc.tr('dashboard.visualInsights'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              final left = _ChartCard(
                title: loc.tr('dashboard.fighterStatusChart'),
                child: _FighterStatusDonut(
                  active: active,
                  disabled: disabled,
                  loading: fightersAsync.isLoading,
                  unavailable: fightersAsync.hasError,
                ),
              );
              final right = _ChartCard(
                title: loc.tr('dashboard.recordsByModule'),
                child: _ModuleBarChart(
                  values: chartValues,
                  allUnavailable: contactsAsync.hasError &&
                      locationsAsync.hasError &&
                      schedulesAsync.hasError &&
                      checkinsAsync.hasError &&
                      notificationsAsync.hasError &&
                      fightersAsync.hasError,
                ),
              );
              if (!isWide) {
                return Column(
                  children: [
                    left,
                    SizedBox(height: AppLayout.mediumGap(context)),
                    right,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: left),
                  SizedBox(width: AppLayout.mediumGap(context)),
                  Expanded(child: right),
                ],
              );
            },
          ),
          SizedBox(height: AppLayout.sectionGap(context)),
          Text(
            loc.tr('dashboard.recentFighters'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppLayout.cardPadding(context)),
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

class _KpiItem {
  const _KpiItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final _KpiItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppLayout.kpiCardWidth(context),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: BrandTheme.vadaRed),
              SizedBox(height: AppLayout.smallGap(context)),
              Text(item.title),
              SizedBox(height: AppLayout.smallGap(context)),
              Text(
                item.value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: AppLayout.mediumGap(context)),
            child,
          ],
        ),
      ),
    );
  }
}

class _FighterStatusDonut extends StatelessWidget {
  const _FighterStatusDonut({
    required this.active,
    required this.disabled,
    required this.loading,
    required this.unavailable,
  });

  final int active;
  final int disabled;
  final bool loading;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    if (loading) {
      return Text(loc.tr('common.loading'));
    }
    if (unavailable) {
      return Text(loc.tr('common.comingSoon'));
    }

    final total = active + disabled;
    final activePercent = total == 0 ? 0.0 : active / total;

    return Row(
      children: [
        SizedBox(
          width: AppLayout.chartDonutSize(context),
          height: AppLayout.chartDonutSize(context),
          child: CustomPaint(
            painter: _DonutPainter(
              activePercent: activePercent,
              activeColor: BrandTheme.vadaRed,
              disabledColor: AppColors.softGray,
            ),
            child: Center(
              child: Text(
                '$total',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
        SizedBox(width: AppLayout.mediumGap(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendRow(
                color: BrandTheme.vadaRed,
                label: '${loc.tr('dashboard.activeFighters')}: $active',
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              _LegendRow(
                color: AppColors.softGray,
                label: '${loc.tr('dashboard.disabledFighters')}: $disabled',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: AppLayout.smallGap(context)),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _ModuleBarChart extends StatelessWidget {
  const _ModuleBarChart({required this.values, required this.allUnavailable});

  final Map<String, int> values;
  final bool allUnavailable;

  @override
  Widget build(BuildContext context) {
    if (allUnavailable) {
      return Text(context.l10n.tr('common.comingSoon'));
    }
    if (values.isEmpty) {
      return Text(context.l10n.tr('dashboard.noChartData'));
    }
    final maxValue = values.values.fold<int>(0, math.max);

    return Column(
      children: values.entries.map((entry) {
        final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;
        return Padding(
          padding: EdgeInsets.only(bottom: AppLayout.smallGap(context)),
          child: Row(
            children: [
              SizedBox(
                width: AppLayout.chartLabelWidth(context),
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: AppLayout.chartBarHeight(context),
                    value: ratio,
                    color: BrandTheme.vadaRed,
                    backgroundColor: AppColors.progressTrack,
                  ),
                ),
              ),
              SizedBox(width: AppLayout.smallGap(context)),
              SizedBox(
                width: AppLayout.chartValueWidth(context),
                child: Text(
                  '${entry.value}',
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.activePercent,
    required this.activeColor,
    required this.disabledColor,
  });

  final double activePercent;
  final Color activeColor;
  final Color disabledColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.14;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = disabledColor);

    final sweep = (2 * math.pi) * activePercent.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        paint..color = activeColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.activePercent != activePercent ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.disabledColor != disabledColor;
  }
}
