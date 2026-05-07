import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/utils/download_file.dart';
import '../../contacts/domain/contact.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../fighters/domain/fighter.dart';
import '../../fighters/presentation/fighters_controller.dart';
import '../../locations/domain/location_record.dart';
import '../../locations/presentation/locations_controller.dart';
import '../../whereabouts/domain/whereabouts_entry.dart';
import '../../whereabouts/presentation/whereabouts_controller.dart';

class ReportNotification {
  const ReportNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.target,
    required this.targetUserId,
    required this.createdAt,
    required this.sentAt,
    required this.errorMessage,
  });

  final String id;
  final String type;
  final String title;
  final String status;
  final String target;
  final String targetUserId;
  final DateTime? createdAt;
  final DateTime? sentAt;
  final String? errorMessage;
}

final reportsNotificationsProvider =
    StreamProvider<List<ReportNotification>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(250)
      .snapshots()
      .map((snap) {
    return snap.docs.map((doc) {
      final data = doc.data();
      DateTime? readTs(dynamic v) {
        if (v == null) return null;
        if (v is DateTime) return v;
        try {
          // ignore: avoid_dynamic_calls
          return v.toDate() as DateTime;
        } catch (_) {
          return null;
        }
      }

      return ReportNotification(
        id: doc.id,
        type: (data['type'] as String? ?? '').trim(),
        title: (data['title'] as String? ?? '').trim(),
        status: (data['status'] as String? ?? '').trim(),
        target: (data['target'] as String? ?? '').trim(),
        targetUserId: (data['targetUserId'] as String? ?? '').trim(),
        createdAt: readTs(data['createdAt']),
        sentAt: readTs(data['sentAt']),
        errorMessage: (data['errorMessage'] as String?)?.trim(),
      );
    }).toList();
  });
});

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  int _tab = 0;
  String _fighterId = '';
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .subtract(const Duration(days: 7)),
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .add(const Duration(days: 7)),
  );

  bool _inRange(DateTime day, DateTimeRange range) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  DateTime? _tryParseYmd(String raw) {
    final v = raw.trim();
    if (v.length != 10) return null;
    final year = int.tryParse(v.substring(0, 4));
    final month = int.tryParse(v.substring(5, 7));
    final day = int.tryParse(v.substring(8, 10));
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _csvEscape(String v) {
    final needsQuotes = v.contains(',') || v.contains('\n') || v.contains('"');
    final escaped = v.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _downloadName(String prefix) {
    final s = _range.start;
    final e = _range.end;
    String ymd(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final fighter = _fighterId.isEmpty ? 'all' : _fighterId;
    return '${prefix}_${fighter}_${ymd(s)}-${ymd(e)}.csv';
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final fightersAsync = ref.watch(fightersStreamProvider);
    final whereaboutsAsync = ref.watch(whereaboutsStreamProvider);
    final notificationsAsync = ref.watch(reportsNotificationsProvider);
    final contactsAsync = ref.watch(contactsStreamProvider);
    final locationsAsync = ref.watch(locationsStreamProvider);

    final fighters = fightersAsync.asData?.value ?? const <Fighter>[];
    final fighterOptions = fighters.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    final contactNameById = <String, String>{};
    for (final c in contactsAsync.asData?.value ?? const <Contact>[]) {
      contactNameById[c.id] = c.name;
    }
    final locationNameById = <String, String>{};
    for (final l in locationsAsync.asData?.value ?? const <LocationRecord>[]) {
      locationNameById[l.id] = l.name;
    }

    String fighterName(String uid) {
      for (final f in fighterOptions) {
        if (f.uid == uid) return f.fullName;
      }
      return uid;
    }

    String locationName(String id) =>
        locationNameById[id] ?? (id.trim().isEmpty ? '—' : id);
    String contactName(String id) =>
        contactNameById[id] ?? (id.trim().isEmpty ? '—' : id);

    String fmtTs(DateTime? dt) {
      if (dt == null) return '—';
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$m-$d $hh:$mm';
    }

    Widget fighterSelector() {
      String? selectedName;
      if (_fighterId.isNotEmpty) {
        selectedName = fighterName(_fighterId);
      }

      return Autocomplete<Fighter>(
        initialValue: TextEditingValue(text: selectedName ?? ''),
        displayStringForOption: (f) => f.fullName,
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          if (q.isEmpty) return fighterOptions;
          return fighterOptions.where((f) => f.fullName.toLowerCase().contains(q));
        },
        onSelected: (f) => setState(() => _fighterId = f.uid),
        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: loc.tr('nav.fighters'),
              hintText: loc.tr('reports.allFighters'),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _fighterId.isEmpty
                  ? null
                  : IconButton(
                      tooltip: loc.tr('common.clear'),
                      onPressed: () {
                        controller.clear();
                        setState(() => _fighterId = '');
                        focusNode.unfocus();
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onSubmitted: (_) => onSubmit(),
          );
        },
      );
    }

    Widget rangeSelector() {
      final label =
          '${_range.start.year}-${_range.start.month.toString().padLeft(2, '0')}-${_range.start.day.toString().padLeft(2, '0')}'
          ' → '
          '${_range.end.year}-${_range.end.month.toString().padLeft(2, '0')}-${_range.end.day.toString().padLeft(2, '0')}';

      return OutlinedButton.icon(
        onPressed: () async {
          final next = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            initialDateRange: _range,
          );
          if (next != null) {
            setState(() => _range = next);
          }
        },
        icon: const Icon(Icons.date_range_outlined),
        label: Text(label),
      );
    }

    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final scopeLabel = _fighterId.isEmpty
        ? loc.tr('reports.allFighters')
        : fighterName(_fighterId);

    Widget header() {
      final tabLabel =
          _tab == 0 ? loc.tr('reports.schedulesTab') : loc.tr('reports.notificationsTab');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VADA Admin',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${loc.tr('nav.reports')} • $tabLabel',
                  style: Theme.of(context).textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              rangeSelector(),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text('${loc.tr('nav.fighters')}: $scopeLabel'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text('${ymd(_range.start)} → ${ymd(_range.end)}'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      );
    }

    Widget tabBar() {
      return SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 0, label: Text(loc.tr('reports.schedulesTab'))),
          ButtonSegment(value: 1, label: Text(loc.tr('reports.notificationsTab'))),
        ],
        selected: {_tab},
        onSelectionChanged: (s) => setState(() => _tab = s.first),
      );
    }

    Widget schedulesReport() {
      final items = whereaboutsAsync.asData?.value ?? const <WhereaboutsEntry>[];
      final filtered = <WhereaboutsEntry>[];
      for (final e in items) {
        if (_fighterId.isNotEmpty && e.fighterId != _fighterId) continue;
        final day = _tryParseYmd(e.date);
        if (day == null) continue;
        if (!_inRange(day, _range)) continue;
        filtered.add(e);
      }
      filtered.sort((a, b) {
        final cd = a.date.compareTo(b.date);
        if (cd != 0) return cd;
        return a.startTime.compareTo(b.startTime);
      });

      final csv = [
        [
          'date',
          'startTime',
          'endTime',
          'fighterName',
          'locationName',
          'contactName',
          'notes',
        ].map(_csvEscape).join(','),
        ...filtered.map((e) => [
              e.date,
              e.startTime,
              e.endTime,
              fighterName(e.fighterId),
              locationName(e.locationId),
              contactName(e.contactId),
              e.notes,
            ].map(_csvEscape).join(',')),
      ].join('\n');

      return Card(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: fighterSelector()),
                  SizedBox(width: AppLayout.smallGap(context)),
                  FilledButton.tonalIcon(
                    onPressed: () => downloadTextFile(
                      filename: _downloadName('schedules'),
                      mimeType: 'text/csv;charset=utf-8',
                      contents: csv,
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(loc.tr('reports.downloadCsv')),
                  ),
                ],
              ),
              SizedBox(height: AppLayout.mediumGap(context)),
              Text(
                loc.tr('reports.resultsCount').replaceAll('{count}', '${filtered.length}'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              if (whereaboutsAsync.isLoading)
                Text(loc.tr('common.loading'))
              else if (filtered.isEmpty)
                Text(loc.tr('reports.noResults'))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Fighter')),
                      DataColumn(label: Text('Location')),
                      DataColumn(label: Text('Contact')),
                      DataColumn(label: Text('Notes')),
                    ],
                    rows: filtered.take(250).map((e) {
                      return DataRow(
                        cells: [
                          DataCell(Text(e.date)),
                          DataCell(Text('${e.startTime}-${e.endTime}')),
                          DataCell(Text(fighterName(e.fighterId))),
                          DataCell(Text(locationName(e.locationId))),
                          DataCell(Text(contactName(e.contactId))),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(
                                e.notes,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget notificationsReport() {
      final items =
          notificationsAsync.asData?.value ?? const <ReportNotification>[];
      final filtered = <ReportNotification>[];
      for (final n in items) {
        if (_fighterId.isNotEmpty &&
            n.targetUserId.isNotEmpty &&
            n.targetUserId != _fighterId) {
          continue;
        }
        final ts = n.createdAt;
        if (ts == null) continue;
        if (!_inRange(ts, _range)) continue;
        filtered.add(n);
      }
      filtered.sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));

      final csv = [
        [
          'createdAt',
          'type',
          'status',
          'targetName',
          'title',
          'errorMessage',
        ]
            .map(_csvEscape)
            .join(','),
        ...filtered.map((n) => [
              (n.createdAt ?? DateTime(1970)).toIso8601String(),
              n.type,
              n.status,
              n.target == 'broadcast'
                  ? loc.tr('reports.broadcast')
                  : fighterName(n.targetUserId),
              n.title,
              n.errorMessage ?? '',
            ].map(_csvEscape).join(',')),
      ].join('\n');

      return Card(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: fighterSelector()),
                  SizedBox(width: AppLayout.smallGap(context)),
                  FilledButton.tonalIcon(
                    onPressed: () => downloadTextFile(
                      filename: _downloadName('notifications'),
                      mimeType: 'text/csv;charset=utf-8',
                      contents: csv,
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(loc.tr('reports.downloadCsv')),
                  ),
                ],
              ),
              SizedBox(height: AppLayout.mediumGap(context)),
              if (notificationsAsync.isLoading)
                Text(loc.tr('common.loading'))
              else if (filtered.isEmpty)
                Text(loc.tr('reports.noResults'))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('Created')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Target')),
                      DataColumn(label: Text('Title')),
                      DataColumn(label: Text('Error')),
                    ],
                    rows: filtered.take(250).map((n) {
                      final targetName = n.target == 'broadcast'
                          ? loc.tr('reports.broadcast')
                          : fighterName(n.targetUserId);
                      return DataRow(
                        cells: [
                          DataCell(Text(fmtTs(n.createdAt))),
                          DataCell(Text(n.type.isEmpty ? '—' : n.type)),
                          DataCell(Text(n.status.isEmpty ? '—' : n.status)),
                          DataCell(Text(targetName)),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(
                                n.title.isEmpty ? '(no title)' : n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(
                                n.errorMessage ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: n.status == 'failed'
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppLayout.pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(),
            SizedBox(height: AppLayout.smallGap(context)),
            tabBar(),
            SizedBox(height: AppLayout.mediumGap(context)),
            if (_tab == 0) schedulesReport() else notificationsReport(),
            SizedBox(height: AppLayout.sectionGap(context)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                loc.tr('reports.noteDownload'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

