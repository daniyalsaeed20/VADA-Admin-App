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
import '../../contacts/presentation/contacts_controller.dart';
import '../../locations/domain/location_record.dart';
import '../../whereabouts/presentation/whereabouts_controller.dart';
import '../../locations/presentation/locations_controller.dart';
import '../../notifications/domain/admin_message_request.dart';

final collectionCountProvider = StreamProvider.family<int, String>((ref, name) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection(name).snapshots().map((snapshot) {
    return snapshot.docs
        .where((doc) => doc.id != FirestoreCollections.metaDoc)
        .length;
  });
});

final recentNotificationsProvider =
    StreamProvider<List<AdminMessageRequest>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirestoreCollections.notifications)
      .orderBy('createdAt', descending: true)
      .limit(25)
      .snapshots()
      .map(
        (snap) => snap.docs
            .where((doc) => doc.id != FirestoreCollections.metaDoc)
            .map(AdminMessageRequest.fromFirestore)
            .toList(),
      );
});

DateTime? _tryParseYmd(String raw) {
  final v = raw.trim();
  if (v.length != 10) return null;
  final year = int.tryParse(v.substring(0, 4));
  final month = int.tryParse(v.substring(5, 7));
  final day = int.tryParse(v.substring(8, 10));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

bool _isInNext7DaysInclusive(DateTime day, DateTime today) {
  final end = today.add(const Duration(days: 7));
  return !day.isBefore(today) && !day.isAfter(end);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final globalSchedulesTodayCountProvider = Provider<int>((ref) {
  final items = ref.watch(whereaboutsStreamProvider);
  return items.when(
    data: (entries) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var count = 0;
      for (final e in entries) {
        final day = _tryParseYmd(e.date);
        if (day == null) continue;
        if (_isSameDay(day, today)) count++;
      }
      return count;
    },
    loading: () => 0,
    error: (_, _) => 0,
  );
});

final globalSchedulesNext7DaysCountProvider = Provider<int>((ref) {
  final items = ref.watch(whereaboutsStreamProvider);
  return items.when(
    data: (entries) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var count = 0;
      for (final e in entries) {
        final day = _tryParseYmd(e.date);
        if (day == null) continue;
        if (_isInNext7DaysInclusive(day, today)) count++;
      }
      return count;
    },
    loading: () => 0,
    error: (_, _) => 0,
  );
});

final fighterUpcomingSchedulesCountProvider =
    Provider.family<int, String>((ref, fighterId) {
  if (fighterId.trim().isEmpty) return 0;
  final items = ref.watch(whereaboutsStreamProvider);
  return items.when(
    data: (entries) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var count = 0;
      for (final e in entries) {
        if (e.fighterId != fighterId.trim()) continue;
        final day = _tryParseYmd(e.date);
        if (day == null) continue;
        if (_isInNext7DaysInclusive(day, today)) count++;
      }
      return count;
    },
    loading: () => 0,
    error: (_, _) => 0,
  );
});

final fighterContactsCountFromSchedulesProvider =
    Provider.family<int, String>((ref, fighterId) {
  if (fighterId.trim().isEmpty) return 0;
  final items = ref.watch(whereaboutsStreamProvider);
  return items.when(
    data: (entries) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final ids = <String>{};
      for (final e in entries) {
        if (e.fighterId != fighterId.trim()) continue;
        final day = _tryParseYmd(e.date);
        if (day == null) continue;
        if (!_isInNext7DaysInclusive(day, today)) continue;
        final id = e.contactId.trim();
        if (id.isNotEmpty) ids.add(id);
      }
      return ids.length;
    },
    loading: () => 0,
    error: (_, _) => 0,
  );
});

final fighterLocationsProvider =
    StreamProvider.family<List<LocationRecord>, String>((ref, fighterId) {
  final firestore = ref.watch(firestoreProvider);
  if (fighterId.trim().isEmpty) {
    return const Stream.empty();
  }
  return firestore
      .collection(FirestoreCollections.locations)
      .snapshots()
      .map((snapshot) {
    final locations = snapshot.docs
        .where((doc) => doc.id != FirestoreCollections.metaDoc)
        .map((doc) => LocationRecord.fromFirestore(doc))
        .where((loc) => loc.assignedFighterIds.contains(fighterId.trim()))
        .toList();
    locations.sort((a, b) => a.name.compareTo(b.name));
    return locations;
  });
});

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String _selectedFighterId = '';

  @override
  Widget build(BuildContext context) {
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
            loc.tr('dashboard.fighterOverview'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          _FighterOverviewCard(
            fighters: fightersData,
            selectedFighterId: _selectedFighterId,
            onSelectedFighterIdChanged: (value) =>
                setState(() => _selectedFighterId = value),
          ),
          SizedBox(height: AppLayout.sectionGap(context)),
          Text(
            loc.tr('dashboard.globalInsights'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          _GlobalInsightsPanel(
            totalFighters: total,
            activeFighters: active,
            disabledFighters: disabled,
          ),
          SizedBox(height: AppLayout.sectionGap(context)),
          Text(
            loc.tr('dashboard.actionCenter'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          _ActionCenterPanel(
            scheduleRequestsCount: scheduleRequestsAsync.asData?.value ?? 0,
            scheduleRequestsLoading: scheduleRequestsAsync.isLoading,
            checkinsCount: checkinsAsync.asData?.value ?? 0,
            checkinsLoading: checkinsAsync.isLoading,
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

class _FighterOverviewCard extends ConsumerWidget {
  const _FighterOverviewCard({
    required this.fighters,
    required this.selectedFighterId,
    required this.onSelectedFighterIdChanged,
  });

  final List<Fighter> fighters;
  final String selectedFighterId;
  final ValueChanged<String> onSelectedFighterIdChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = fighters.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
    String? selectedName;
    if (selectedFighterId.isNotEmpty) {
      for (final f in sorted) {
        if (f.uid == selectedFighterId) {
          selectedName = f.fullName;
          break;
        }
      }
    }

    final options = sorted
        .map((f) => _FighterOption(uid: f.uid, label: f.fullName))
        .toList();

    final contactsFromSchedulesCount =
        ref.watch(fighterContactsCountFromSchedulesProvider(selectedFighterId));
    final upcomingSchedulesCount =
        ref.watch(fighterUpcomingSchedulesCountProvider(selectedFighterId));
    final locationsAsync = ref.watch(fighterLocationsProvider(selectedFighterId));
    final contactsAsync = ref.watch(contactsStreamProvider);
    final allLocationsAsync = ref.watch(locationsStreamProvider);
    final whereaboutsAsync = ref.watch(whereaboutsStreamProvider);

    Fighter? selectedFighter;
    if (selectedFighterId.isNotEmpty) {
      for (final f in fighters) {
        if (f.uid == selectedFighterId) {
          selectedFighter = f;
          break;
        }
      }
    }

    String initialsFor(String name) {
      final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) return '?';
      String firstChar(String s) => s.isEmpty ? '' : s.substring(0, 1);
      final first = firstChar(parts.first);
      final second = parts.length > 1 ? firstChar(parts[1]) : '';
      final value = (first + second).trim();
      return value.isEmpty ? '?' : value.toUpperCase();
    }

    String? locationNameForId(String id) {
      final items = allLocationsAsync.asData?.value;
      if (items == null) return null;
      for (final it in items) {
        if (it.id == id) return it.name;
      }
      return null;
    }

    String? contactNameForId(String id) {
      final items = contactsAsync.asData?.value;
      if (items == null) return null;
      for (final it in items) {
        if (it.id == id) return it.name;
      }
      return null;
    }

    List<_UpcomingScheduleRow> upcomingPreview() {
      if (selectedFighterId.isEmpty) return const [];
      final entries = whereaboutsAsync.asData?.value;
      if (entries == null) return const [];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final rows = <_UpcomingScheduleRow>[];
      for (final e in entries) {
        if (e.fighterId != selectedFighterId) continue;
        final day = _tryParseYmd(e.date);
        if (day == null) continue;
        if (!_isInNext7DaysInclusive(day, today)) continue;
        rows.add(
          _UpcomingScheduleRow(
            date: e.date,
            time: '${e.startTime}-${e.endTime}',
            locationName:
                locationNameForId(e.locationId) ?? 'Location',
            contactName: contactNameForId(e.contactId) ?? 'Contact',
          ),
        );
      }
      rows.sort((a, b) => a.date.compareTo(b.date));
      return rows.take(3).toList();
    }

    final previewRows = upcomingPreview();

    final scheme = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.sizeOf(context).width < 860;

    Widget selectorRow() {
      return Row(
        children: [
          Expanded(
            child: Autocomplete<_FighterOption>(
              initialValue: TextEditingValue(text: selectedName ?? ''),
              displayStringForOption: (o) => o.label,
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return options;
                return options.where((o) => o.label.toLowerCase().contains(q));
              },
              onSelected: (o) => onSelectedFighterIdChanged(o.uid),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search fighter',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: selectedFighterId.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              controller.clear();
                              onSelectedFighterIdChanged('');
                              focusNode.unfocus();
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onSubmitted: (_) => onSubmit(),
                );
              },
            ),
          ),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNarrow) ...[
              Text('Fighter overview', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: AppLayout.smallGap(context) * 0.6),
              Text(
                'Quick snapshot of schedules, contacts and assigned locations.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              selectorRow(),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fighter overview',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: AppLayout.smallGap(context) * 0.6),
                        Text(
                          'Quick snapshot of schedules, contacts and assigned locations.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppLayout.smallGap(context)),
                  SizedBox(width: 460, child: selectorRow()),
                ],
              ),
            ],
            SizedBox(height: AppLayout.mediumGap(context)),
            if (selectedFighterId.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_search_outlined, color: scheme.onSurfaceVariant),
                    SizedBox(width: AppLayout.smallGap(context)),
                    Expanded(
                      child: Text(
                        'Choose a fighter to see their upcoming schedules, contacts and locations.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Text(
                    initialsFor(selectedFighter?.fullName ?? selectedName ?? ''),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                title: Text(
                  selectedFighter?.fullName ?? (selectedName ?? 'Fighter'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: selectedFighter == null
                    ? null
                    : Text(
                        selectedFighter.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: Chip(
                  label: Text(
                    selectedFighter != null && selectedFighter.disabled ? 'Disabled' : 'Active',
                  ),
                ),
              ),
              Divider(height: AppLayout.mediumGap(context)),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 980 ? 3 : 1;
                  final tiles = [
                    _OverviewStatCard(
                      title: 'Schedules (next 7 days)',
                      value: '$upcomingSchedulesCount',
                      icon: Icons.calendar_month_outlined,
                      onTap: () => context.go(AppRoutes.whereabouts),
                    ),
                    _OverviewStatCard(
                      title: 'Contacts (from schedules)',
                      value: '$contactsFromSchedulesCount',
                      icon: Icons.contact_phone_outlined,
                      onTap: () => context.go(AppRoutes.contacts),
                    ),
                    _OverviewStatCard(
                      title: 'Assigned locations',
                      value: locationsAsync.when(
                        data: (items) => '${items.length}',
                        loading: () => context.l10n.tr('common.loading'),
                        error: (_, _) => '0',
                      ),
                      icon: Icons.location_on_outlined,
                      onTap: () => context.go(AppRoutes.locations),
                    ),
                  ];
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: crossAxisCount == 1 ? 4.8 : 3.6,
                    children: tiles,
                  );
                },
              ),
              SizedBox(height: AppLayout.mediumGap(context)),
              _UpcomingSchedulesPreview(rows: previewRows),
              SizedBox(height: AppLayout.mediumGap(context)),
              _AssignedLocationsPreview(locationsAsync: locationsAsync),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlobalInsightsPanel extends ConsumerWidget {
  const _GlobalInsightsPanel({
    required this.totalFighters,
    required this.activeFighters,
    required this.disabledFighters,
  });

  final int totalFighters;
  final int activeFighters;
  final int disabledFighters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.l10n;
    final schedulesToday = ref.watch(globalSchedulesTodayCountProvider);
    final schedulesNext7 = ref.watch(globalSchedulesNext7DaysCountProvider);
    final scheme = Theme.of(context).colorScheme;

    final activeRate = totalFighters == 0
        ? 0
        : ((activeFighters / totalFighters) * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final crossAxisCount = isWide ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.8 : 2.6,
          children: [
            _InsightTile(
              title: loc.tr('dashboard.schedulesToday'),
              value: '$schedulesToday',
              subtitle: loc.tr('dashboard.allFighters'),
              icon: Icons.today_outlined,
              tone: scheme.secondary,
              onTap: () => context.go(AppRoutes.whereabouts),
            ),
            _InsightTile(
              title: loc.tr('dashboard.upcoming7Days'),
              value: '$schedulesNext7',
              subtitle: loc.tr('dashboard.allFighters'),
              icon: Icons.date_range_outlined,
              tone: scheme.tertiary,
              onTap: () => context.go(AppRoutes.whereabouts),
            ),
            _InsightTile(
              title: loc.tr('dashboard.activeFightersTile'),
              value: '$activeFighters',
              subtitle: loc.tr('dashboard.activeRate')
                  .replaceAll('{rate}', '$activeRate')
                  .replaceAll('{total}', '$totalFighters'),
              icon: Icons.person_outlined,
              tone: BrandTheme.vadaRed,
              onTap: () => context.go(AppRoutes.fighters),
            ),
            _InsightTile(
              title: loc.tr('dashboard.inactiveFightersTile'),
              value: '$disabledFighters',
              subtitle: totalFighters == 0
                  ? '—'
                  : loc.tr('dashboard.inactiveAccounts'),
              icon: Icons.person_off_outlined,
              tone: scheme.onSurfaceVariant,
              onTap: () => context.go(AppRoutes.fighters),
            ),
          ],
        );
      },
    );
  }
}

class _ActionCenterPanel extends ConsumerWidget {
  const _ActionCenterPanel({
    required this.scheduleRequestsCount,
    required this.scheduleRequestsLoading,
    required this.checkinsCount,
    required this.checkinsLoading,
  });

  final int scheduleRequestsCount;
  final bool scheduleRequestsLoading;
  final int checkinsCount;
  final bool checkinsLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final notificationsAsync = ref.watch(recentNotificationsProvider);

    String formatTs(DateTime? dt) {
      if (dt == null) return '—';
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$m-$d $hh:$mm';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionRow(
              icon: Icons.swap_horiz_outlined,
              title: loc.tr('dashboard.scheduleRequestsShort'),
              subtitle: loc.tr('dashboard.comingSoonModule'),
              value: scheduleRequestsLoading
                  ? loc.tr('common.loading')
                  : '$scheduleRequestsCount',
              tone: scheme.tertiary,
              onTap: () => context.go(AppRoutes.scheduleRequests),
            ),
            const Divider(height: 18),
            _ActionRow(
              icon: Icons.gps_fixed_outlined,
              title: loc.tr('nav.checkins'),
              subtitle: loc.tr('dashboard.comingSoonModule'),
              value: checkinsLoading ? loc.tr('common.loading') : '$checkinsCount',
              tone: scheme.secondary,
              onTap: () => context.go(AppRoutes.checkins),
            ),
            const Divider(height: 18),
            Row(
              children: [
                Icon(Icons.notifications_outlined, color: scheme.onSurfaceVariant),
                SizedBox(width: AppLayout.smallGap(context)),
                Expanded(
                  child: Text(
                    loc.tr('dashboard.notificationsHealth'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.notifications),
                  child: Text(loc.tr('common.open')),
                ),
              ],
            ),
            SizedBox(height: AppLayout.smallGap(context)),
            notificationsAsync.when(
              loading: () => Text(
                context.l10n.tr('common.loading'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              error: (_, _) => Text(
                loc.tr('common.loading'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              data: (items) {
                var pending = 0;
                var failed = 0;
                for (final it in items) {
                  if (it.status == 'pending' || it.status == 'processing') pending++;
                  if (it.status == 'failed') failed++;
                }
                final headline = Row(
                  children: [
                    _MiniPill(
                      label: loc.tr('common.pending'),
                      value: '$pending',
                      fg: scheme.onSurfaceVariant,
                      bg: scheme.surfaceContainerHighest,
                    ),
                    const SizedBox(width: 8),
                    _MiniPill(
                      label: loc.tr('common.failed'),
                      value: '$failed',
                      fg: scheme.error,
                      bg: scheme.error.withValues(alpha: 0.10),
                    ),
                  ],
                );

                final attention = items
                    .where((it) =>
                        it.status == 'failed' ||
                        it.status == 'pending' ||
                        it.status == 'processing')
                    .take(5)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headline,
                    SizedBox(height: AppLayout.smallGap(context)),
                    if (attention.isEmpty)
                      Text(
                        loc.tr('dashboard.noNotificationsAttention'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: attention.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final it = attention[index];
                          final type = it.target == 'broadcast'
                              ? 'Broadcast'
                              : (it.targetUserId == null || it.targetUserId!.isEmpty
                                  ? 'User'
                                  : 'User');
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              it.title.isEmpty ? '(no title)' : it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${it.status} • ${formatTs(it.createdAt)} • $type',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              it.status == 'failed'
                                  ? Icons.error_outline
                                  : Icons.timelapse_outlined,
                              color: it.status == 'failed'
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                            onTap: () => context.go(AppRoutes.notifications),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.value,
    required this.fg,
    required this.bg,
  });

  final String label;
  final String value;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tone, size: 18),
            ),
            SizedBox(width: AppLayout.smallGap(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          color: scheme.surface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tone, size: 18),
            ),
            SizedBox(width: AppLayout.smallGap(context)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // In some tab views the tile height gets very small; avoid
                  // RenderFlex overflow by hiding the subtitle when needed.
                  final showSubtitle = constraints.maxHeight.isInfinite
                      ? true
                      : constraints.maxHeight >= 76;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (showSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _UpcomingScheduleRow {
  const _UpcomingScheduleRow({
    required this.date,
    required this.time,
    required this.locationName,
    required this.contactName,
  });

  final String date;
  final String time;
  final String locationName;
  final String contactName;
}

class _UpcomingSchedulesPreview extends StatelessWidget {
  const _UpcomingSchedulesPreview({required this.rows});

  final List<_UpcomingScheduleRow> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        color: scheme.surface,
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.schedule_outlined, color: scheme.onSurfaceVariant),
            title: const Text('Upcoming (next 7 days)'),
            subtitle: Text(
              rows.isEmpty ? 'No schedules found.' : 'Next ${rows.length} entries',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            trailing: TextButton(
              onPressed: () => context.go(AppRoutes.whereabouts),
              child: const Text('View all'),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppLayout.cardPadding(context),
              vertical: 2,
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.all(AppLayout.cardPadding(context)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No schedules in the next 7 days.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = rows[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppLayout.cardPadding(context),
                    vertical: 0,
                  ),
                  leading: SizedBox(
                    width: 86,
                    child: Text(
                      r.date,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  title: Text(
                    r.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${r.time} • ${r.contactName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  onTap: () => context.go(AppRoutes.whereabouts),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AssignedLocationsPreview extends StatelessWidget {
  const _AssignedLocationsPreview({required this.locationsAsync});

  final AsyncValue<List<LocationRecord>> locationsAsync;

  @override
  Widget build(BuildContext context) {
    return locationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final preview = items.take(8).toList();
        final remaining = items.length - preview.length;

        IconData iconForType(String raw) {
          switch (raw.trim().toLowerCase()) {
            case 'gym':
              return Icons.fitness_center_outlined;
            case 'hotel':
              return Icons.hotel_outlined;
            case 'arena':
              return Icons.stadium_outlined;
            case 'airport':
              return Icons.flight_outlined;
            default:
              return Icons.place_outlined;
          }
        }

        Widget chipFor(LocationRecord item) {
          final address = item.address.trim();
          final tooltip = address.isEmpty ? item.name : '${item.name}\n$address';
          return Tooltip(
            message: tooltip,
            waitDuration: const Duration(milliseconds: 450),
            child: InputChip(
              avatar: Icon(
                iconForType(item.type),
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              label: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
              ),
              labelStyle: Theme.of(context).textTheme.bodyMedium,
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: AppColors.border),
              backgroundColor: scheme.surface,
              onPressed: () => context.go(AppRoutes.locations),
            ),
          );
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            color: Theme.of(context).colorScheme.surface,
          ),
          padding: EdgeInsets.all(AppLayout.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place_outlined, color: scheme.onSurfaceVariant),
                  SizedBox(width: AppLayout.smallGap(context)),
                  Expanded(
                    child: Text(
                      'Assigned locations',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${items.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...preview.map(chipFor),
                  if (remaining > 0)
                    ActionChip(
                      label: Text('+$remaining more'),
                      onPressed: () => context.go(AppRoutes.locations),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  const _OverviewStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          color: Theme.of(context).colorScheme.surface,
        ),
        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
        child: Row(
          children: [
            Icon(icon, color: BrandTheme.vadaRed),
            SizedBox(width: AppLayout.smallGap(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppLayout.smallGap(context) * 0.6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _FighterOption {
  const _FighterOption({required this.uid, required this.label});

  final String uid;
  final String label;
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
