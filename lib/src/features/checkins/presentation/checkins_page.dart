import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_layout.dart';
import '../../fighters/domain/fighter.dart';
import '../../fighters/presentation/fighters_controller.dart';
import '../domain/checkin_record.dart';
import 'checkins_controller.dart';

class CheckinsPage extends ConsumerStatefulWidget {
  const CheckinsPage({super.key});

  @override
  ConsumerState<CheckinsPage> createState() => _CheckinsPageState();
}

class _CheckinsPageState extends ConsumerState<CheckinsPage> {
  static const List<int> _rowsPerPageOptions = [10, 20, 50];
  final TextEditingController _searchController = TextEditingController();
  int _rowsPerPage = _rowsPerPageOptions.first;
  int _page = 0;
  _TimeRange _timeRange = _TimeRange.today;
  _SeverityFilter _severityFilter = _SeverityFilter.all;
  bool _labelOnly = false;
  bool _anomaliesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final checkinsAsync = ref.watch(checkinsStreamProvider);
    final fightersAsync = ref.watch(fightersStreamProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 980;
    final scheme = Theme.of(context).colorScheme;

    final fighters = fightersAsync.asData?.value ?? const <Fighter>[];
    final fighterNameById = {
      for (final fighter in fighters) fighter.uid: fighter.fullName,
    };

    return Padding(
      padding: EdgeInsets.all(AppLayout.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('nav.checkins'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          Text(
            'Review incoming GPS check-ins from fighters.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: AppLayout.mediumGap(context)),
          _OperationsBanner(),
          SizedBox(height: AppLayout.mediumGap(context)),
          Expanded(
            child: checkinsAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: AppLayout.smallGap(context)),
                    Text(loc.tr('common.loading')),
                  ],
                ),
              ),
              error: (_, _) => const Center(
                child: Text('Could not load check-ins.'),
              ),
              data: (checkins) {
                final analytics = _CheckinAnalytics.fromRecords(checkins);
                final anomalies = _detectAnomalies(checkins, fighterNameById);
                if (checkins.isEmpty) {
                  return const Center(
                    child: Text('No check-ins found yet.'),
                  );
                }

                final filtered = _filterCheckins(checkins, fighterNameById);
                if (filtered.isEmpty) {
                  return Column(
                    children: [
                      _AnalyticsKpis(analytics: analytics),
                      SizedBox(height: AppLayout.mediumGap(context)),
                      _FiltersBar(
                        searchController: _searchController,
                        timeRange: _timeRange,
                        onTimeRangeChanged: (value) {
                          setState(() {
                            _timeRange = value;
                            _page = 0;
                          });
                        },
                        severityFilter: _severityFilter,
                        onSeverityFilterChanged: (value) {
                          setState(() {
                            _severityFilter = value;
                            _page = 0;
                          });
                        },
                        labelOnly: _labelOnly,
                        onLabelOnlyChanged: (value) {
                          setState(() {
                            _labelOnly = value;
                            _page = 0;
                          });
                        },
                        anomaliesOnly: _anomaliesOnly,
                        onAnomaliesOnlyChanged: (value) {
                          setState(() {
                            _anomaliesOnly = value;
                            _page = 0;
                          });
                        },
                        onSearchChanged: (_) => setState(() => _page = 0),
                      ),
                      SizedBox(height: AppLayout.mediumGap(context)),
                      const Expanded(
                        child: Center(
                          child: Text('No check-ins match current filters.'),
                        ),
                      ),
                    ],
                  );
                }

                final totalPages = math.max(
                  1,
                  (filtered.length / _rowsPerPage).ceil(),
                );
                final geoInsights = _GeoInsights.fromRecords(filtered);
                final currentPage = _page.clamp(0, totalPages - 1).toInt();
                final startIndex = currentPage * _rowsPerPage;
                final endIndex = math.min(
                  startIndex + _rowsPerPage,
                  filtered.length,
                );
                final pageItems = filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          _AnalyticsKpis(analytics: analytics),
                          SizedBox(height: AppLayout.mediumGap(context)),
                          _FiltersBar(
                            searchController: _searchController,
                            timeRange: _timeRange,
                            onTimeRangeChanged: (value) {
                              setState(() {
                                _timeRange = value;
                                _page = 0;
                              });
                            },
                            severityFilter: _severityFilter,
                            onSeverityFilterChanged: (value) {
                              setState(() {
                                _severityFilter = value;
                                _page = 0;
                              });
                            },
                            labelOnly: _labelOnly,
                            onLabelOnlyChanged: (value) {
                              setState(() {
                                _labelOnly = value;
                                _page = 0;
                              });
                            },
                            anomaliesOnly: _anomaliesOnly,
                            onAnomaliesOnlyChanged: (value) {
                              setState(() {
                                _anomaliesOnly = value;
                                _page = 0;
                              });
                            },
                            onSearchChanged: (_) => setState(() => _page = 0),
                          ),
                          SizedBox(height: AppLayout.mediumGap(context)),
                          _AnomalyQueue(
                            anomalies: anomalies,
                            onReviewAnomalies: () {
                              setState(() {
                                _anomaliesOnly = true;
                                _timeRange = _TimeRange.last7Days;
                                _severityFilter = _SeverityFilter.warning;
                                _page = 0;
                              });
                            },
                          ),
                          SizedBox(height: AppLayout.mediumGap(context)),
                          _GeoInsightsCard(insights: geoInsights),
                          SizedBox(height: AppLayout.mediumGap(context)),
                          _ExportBar(
                            onCopyCsv: () => _copyCsvReport(
                              filtered: filtered,
                              fighterNameById: fighterNameById,
                            ),
                          ),
                          SizedBox(height: AppLayout.mediumGap(context)),
                          if (isNarrow)
                            ...pageItems.map((item) {
                              final fighterName =
                                  fighterNameById[item.fighterId] ??
                                      item.fighterId;
                              final severity = _severityFor(item);
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppLayout.smallGap(context),
                                ),
                                child: Card(
                                  child: ListTile(
                                    onTap: () => _showDetailsDialog(
                                      context: context,
                                      record: item,
                                      fighterName: fighterName,
                                    ),
                                    title: Text(
                                      fighterName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${_formatDate(item.capturedAt ?? item.createdAt)}'
                                      '\n${_formatCoordinate(item.latitude)}, ${_formatCoordinate(item.longitude)}'
                                      '\n${severity.label}',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      tooltip: 'Open map',
                                      onPressed: () => _openExternalMap(item),
                                      icon: const Icon(Icons.map_outlined),
                                    ),
                                  ),
                                ),
                              );
                            })
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Fighter')),
                                  DataColumn(label: Text('Captured At')),
                                  DataColumn(label: Text('Coordinates')),
                                  DataColumn(label: Text('Accuracy (m)')),
                                  DataColumn(label: Text('Label')),
                                  DataColumn(label: Text('Severity')),
                                  DataColumn(label: Text('Map')),
                                  DataColumn(label: Text('Details')),
                                ],
                                rows: pageItems.map((item) {
                                  final fighterName =
                                      fighterNameById[item.fighterId] ??
                                          item.fighterId;
                                  final severity = _severityFor(item);
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        SizedBox(
                                          width: 220,
                                          child: Text(
                                            fighterName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _formatDate(
                                            item.capturedAt ?? item.createdAt,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${_formatCoordinate(item.latitude)}, '
                                          '${_formatCoordinate(item.longitude)}',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item.accuracyMeters == null
                                              ? '-'
                                              : item.accuracyMeters!
                                                  .toStringAsFixed(1),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            item.label ?? '-',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(severity.label)),
                                      DataCell(
                                        IconButton(
                                          tooltip: 'Open map',
                                          onPressed: () => _openExternalMap(item),
                                          icon: const Icon(Icons.map_outlined),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          tooltip: 'View details',
                                          onPressed: () => _showDetailsDialog(
                                            context: context,
                                            record: item,
                                            fighterName: fighterName,
                                          ),
                                          icon: const Icon(Icons.open_in_new),
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
                    SizedBox(height: AppLayout.smallGap(context)),
                    _Pagination(
                      rowsPerPage: _rowsPerPage,
                      rowsPerPageOptions: _rowsPerPageOptions,
                      startIndex: startIndex,
                      endIndex: endIndex,
                      totalCount: filtered.length,
                      currentPage: currentPage,
                      totalPages: totalPages,
                      onRowsPerPageChanged: (value) {
                        setState(() {
                          _rowsPerPage = value;
                          _page = 0;
                        });
                      },
                      onPreviousPage: currentPage == 0
                          ? null
                          : () {
                              setState(() => _page = currentPage - 1);
                            },
                      onNextPage: currentPage >= totalPages - 1
                          ? null
                          : () {
                              setState(() => _page = currentPage + 1);
                            },
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: AppLayout.smallGap(context)),
            padding: EdgeInsets.all(AppLayout.smallGap(context)),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Phase 2 active: anomaly queue and data-quality flags. '
              'Next: geofence and map insights.',
            ),
          ),
        ],
      ),
    );
  }

  List<CheckinRecord> _filterCheckins(
    List<CheckinRecord> items,
    Map<String, String> fighterNameById,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      if (!_isInTimeRange(item)) {
        return false;
      }
      final severity = _severityFor(item);
      if (!_matchesSeverityFilter(severity)) {
        return false;
      }
      if (_labelOnly && (item.label == null || item.label!.trim().isEmpty)) {
        return false;
      }
      if (_anomaliesOnly && _anomalyFlags(item).isEmpty) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final fighterName =
          (fighterNameById[item.fighterId] ?? item.fighterId).toLowerCase();
      final label = (item.label ?? '').toLowerCase();
      final lat = _formatCoordinate(item.latitude);
      final lng = _formatCoordinate(item.longitude);
      return fighterName.contains(query) ||
          label.contains(query) ||
          lat.contains(query) ||
          lng.contains(query);
    }).toList();
  }

  List<_CheckinAnomaly> _detectAnomalies(
    List<CheckinRecord> items,
    Map<String, String> fighterNameById,
  ) {
    final results = <_CheckinAnomaly>[];
    for (final item in items) {
      if (!_isInTimeRange(item)) {
        continue;
      }
      final fighterName = fighterNameById[item.fighterId] ?? item.fighterId;
      final flags = _anomalyFlags(item);
      for (final flag in flags) {
        results.add(
          _CheckinAnomaly(
            record: item,
            fighterName: fighterName,
            severity: flag.severity,
            title: flag.title,
            description: flag.description,
          ),
        );
      }
    }
    results.sort((a, b) {
      final aTime = a.record.capturedAt ?? a.record.createdAt;
      final bTime = b.record.capturedAt ?? b.record.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return results;
  }

  List<_AnomalyFlag> _anomalyFlags(CheckinRecord record) {
    final flags = <_AnomalyFlag>[];
    if (record.latitude == 0 && record.longitude == 0) {
      flags.add(
        const _AnomalyFlag(
          severity: _CheckinSeverity.critical,
          title: 'Invalid location',
          description: 'Coordinates are 0,0 and likely unusable.',
        ),
      );
    }
    final accuracy = record.accuracyMeters;
    if (accuracy != null && accuracy > 50) {
      flags.add(
        _AnomalyFlag(
          severity: _CheckinSeverity.critical,
          title: 'Poor GPS quality',
          description: 'Accuracy ${accuracy.toStringAsFixed(1)}m exceeds 50m.',
        ),
      );
    } else if (accuracy != null && accuracy > 20) {
      flags.add(
        _AnomalyFlag(
          severity: _CheckinSeverity.warning,
          title: 'Weak GPS quality',
          description: 'Accuracy ${accuracy.toStringAsFixed(1)}m exceeds 20m.',
        ),
      );
    }

    final captured = record.capturedAt;
    final created = record.createdAt;
    if (captured != null && created != null) {
      final lagMinutes = created.difference(captured).inMinutes;
      if (lagMinutes > 20) {
        flags.add(
          _AnomalyFlag(
            severity: _CheckinSeverity.warning,
            title: 'Delayed ingestion',
            description: 'Server write lag is ${lagMinutes}m.',
          ),
        );
      }
    }

    if (record.label == null || record.label!.trim().isEmpty) {
      flags.add(
        const _AnomalyFlag(
          severity: _CheckinSeverity.info,
          title: 'Missing label',
          description: 'No user label was provided.',
        ),
      );
    }
    return flags;
  }

  bool _isInTimeRange(CheckinRecord record) {
    final timestamp = record.capturedAt ?? record.createdAt;
    if (timestamp == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localTimestamp = timestamp.toLocal();
    switch (_timeRange) {
      case _TimeRange.today:
        return localTimestamp.isAfter(today) || localTimestamp == today;
      case _TimeRange.last7Days:
        return localTimestamp.isAfter(now.subtract(const Duration(days: 7)));
      case _TimeRange.last30Days:
        return localTimestamp.isAfter(now.subtract(const Duration(days: 30)));
      case _TimeRange.allTime:
        return true;
    }
  }

  _CheckinSeverity _severityFor(CheckinRecord record) {
    final accuracy = record.accuracyMeters;
    if (accuracy == null) {
      return _CheckinSeverity.info;
    }
    if (accuracy > 50) {
      return _CheckinSeverity.critical;
    }
    if (accuracy > 20) {
      return _CheckinSeverity.warning;
    }
    return _CheckinSeverity.good;
  }

  bool _matchesSeverityFilter(_CheckinSeverity severity) {
    switch (_severityFilter) {
      case _SeverityFilter.all:
        return true;
      case _SeverityFilter.good:
        return severity == _CheckinSeverity.good;
      case _SeverityFilter.warning:
        return severity == _CheckinSeverity.warning;
      case _SeverityFilter.critical:
        return severity == _CheckinSeverity.critical;
      case _SeverityFilter.info:
        return severity == _CheckinSeverity.info;
    }
  }

  void _showDetailsDialog({
    required BuildContext context,
    required CheckinRecord record,
    required String fighterName,
  }) {
    final severity = _severityFor(record);
    final googleMapsUrl = _googleMapsUri(record);
    final openStreetMapUrl = _openStreetMapUri(record);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Check-in details'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Fighter', value: fighterName),
              _DetailRow(label: 'Fighter ID', value: record.fighterId),
              _DetailRow(label: 'Severity', value: severity.label),
              _DetailRow(
                label: 'Captured At',
                value: _formatDate(record.capturedAt),
              ),
              _DetailRow(
                label: 'Saved At',
                value: _formatDate(record.createdAt),
              ),
              _DetailRow(
                label: 'Timestamp (ms)',
                value: '${record.timestampMillis}',
              ),
              _DetailRow(
                label: 'Latitude',
                value: _formatCoordinate(record.latitude),
              ),
              _DetailRow(
                label: 'Longitude',
                value: _formatCoordinate(record.longitude),
              ),
              _DetailRow(
                label: 'Accuracy (m)',
                value: record.accuracyMeters == null
                    ? '-'
                    : record.accuracyMeters!.toStringAsFixed(1),
              ),
              _DetailRow(label: 'Label', value: record.label ?? '-'),
              _DetailRow(label: 'Doc ID', value: record.id),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _openMapUrl(googleMapsUrl),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Google Maps'),
          ),
          TextButton.icon(
            onPressed: () => _openMapUrl(openStreetMapUrl),
            icon: const Icon(Icons.public),
            label: const Text('OpenStreetMap'),
          ),
          TextButton.icon(
            onPressed: () => Clipboard.setData(
              ClipboardData(text: googleMapsUrl.toString()),
            ),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy map URL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(value.toLocal());
  }

  String _formatCoordinate(double value) {
    return value.toStringAsFixed(6);
  }

  Uri _googleMapsUri(CheckinRecord record) {
    final lat = record.latitude.toStringAsFixed(6);
    final lng = record.longitude.toStringAsFixed(6);
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  }

  Uri _openStreetMapUri(CheckinRecord record) {
    final lat = record.latitude.toStringAsFixed(6);
    final lng = record.longitude.toStringAsFixed(6);
    return Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng');
  }

  Future<void> _openExternalMap(CheckinRecord record) async {
    await _openMapUrl(_googleMapsUri(record));
  }

  Future<void> _openMapUrl(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $uri')),
    );
  }

  Future<void> _copyCsvReport({
    required List<CheckinRecord> filtered,
    required Map<String, String> fighterNameById,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'docId,fighterId,fighterName,capturedAt,createdAt,latitude,longitude,accuracyMeters,label,severity,anomalyCount',
    );
    for (final item in filtered) {
      final anomalies = _anomalyFlags(item);
      final fighterName = fighterNameById[item.fighterId] ?? item.fighterId;
      final captured = item.capturedAt?.toIso8601String() ?? '';
      final created = item.createdAt?.toIso8601String() ?? '';
      final label = (item.label ?? '').replaceAll(',', ' ');
      buffer.writeln(
        '${item.id},${item.fighterId},$fighterName,$captured,$created,${item.latitude},${item.longitude},${item.accuracyMeters ?? ''},$label,${_severityFor(item).label},${anomalies.length}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV copied (${filtered.length} rows).')),
    );
  }
}

enum _TimeRange {
  today('Today'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  allTime('All time');

  const _TimeRange(this.label);
  final String label;
}

enum _SeverityFilter {
  all('All severities'),
  good('Good'),
  warning('Warning'),
  critical('Critical'),
  info('No accuracy');

  const _SeverityFilter(this.label);
  final String label;
}

enum _CheckinSeverity {
  good('Good'),
  warning('Warning'),
  critical('Critical'),
  info('No accuracy');

  const _CheckinSeverity(this.label);
  final String label;
}

class _CheckinAnalytics {
  const _CheckinAnalytics({
    required this.totalToday,
    required this.totalLast7Days,
    required this.uniqueFightersLast7Days,
    required this.averageAccuracy,
    required this.criticalCountLast7Days,
  });

  final int totalToday;
  final int totalLast7Days;
  final int uniqueFightersLast7Days;
  final double averageAccuracy;
  final int criticalCountLast7Days;

  factory _CheckinAnalytics.fromRecords(List<CheckinRecord> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last7 = now.subtract(const Duration(days: 7));
    int totalToday = 0;
    int totalLast7Days = 0;
    int critical = 0;
    final fighters = <String>{};
    final accuracies = <double>[];

    for (final record in records) {
      final timestamp = record.capturedAt ?? record.createdAt;
      if (timestamp == null) {
        continue;
      }
      final localTimestamp = timestamp.toLocal();
      if (localTimestamp.isAfter(today) || localTimestamp == today) {
        totalToday++;
      }
      if (localTimestamp.isAfter(last7)) {
        totalLast7Days++;
        fighters.add(record.fighterId);
        if ((record.accuracyMeters ?? 0) > 50) {
          critical++;
        }
      }
      if (record.accuracyMeters != null) {
        accuracies.add(record.accuracyMeters!);
      }
    }

    final average = accuracies.isEmpty
        ? 0.0
        : accuracies.reduce((a, b) => a + b) / accuracies.length.toDouble();
    return _CheckinAnalytics(
      totalToday: totalToday,
      totalLast7Days: totalLast7Days,
      uniqueFightersLast7Days: fighters.length,
      averageAccuracy: average,
      criticalCountLast7Days: critical,
    );
  }
}

class _AnalyticsKpis extends StatelessWidget {
  const _AnalyticsKpis({required this.analytics});

  final _CheckinAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppLayout.mediumGap(context),
      runSpacing: AppLayout.mediumGap(context),
      children: [
        _KpiCard(
          title: 'Check-ins today',
          value: '${analytics.totalToday}',
          subtitle: 'Daily monitoring',
          icon: Icons.today_outlined,
        ),
        _KpiCard(
          title: 'Check-ins (7d)',
          value: '${analytics.totalLast7Days}',
          subtitle: 'Rolling weekly volume',
          icon: Icons.insights_outlined,
        ),
        _KpiCard(
          title: 'Unique fighters (7d)',
          value: '${analytics.uniqueFightersLast7Days}',
          subtitle: 'Coverage',
          icon: Icons.groups_outlined,
        ),
        _KpiCard(
          title: 'Avg GPS accuracy',
          value: '${analytics.averageAccuracy.toStringAsFixed(1)} m',
          subtitle: 'Lower is better',
          icon: Icons.gps_fixed,
        ),
        _KpiCard(
          title: 'Critical GPS (7d)',
          value: '${analytics.criticalCountLast7Days}',
          subtitle: 'Accuracy > 50m',
          icon: Icons.warning_amber_outlined,
        ),
      ],
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.timeRange,
    required this.onTimeRangeChanged,
    required this.severityFilter,
    required this.onSeverityFilterChanged,
    required this.labelOnly,
    required this.onLabelOnlyChanged,
    required this.anomaliesOnly,
    required this.onAnomaliesOnlyChanged,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final _TimeRange timeRange;
  final ValueChanged<_TimeRange> onTimeRangeChanged;
  final _SeverityFilter severityFilter;
  final ValueChanged<_SeverityFilter> onSeverityFilterChanged;
  final bool labelOnly;
  final ValueChanged<bool> onLabelOnlyChanged;
  final bool anomaliesOnly;
  final ValueChanged<bool> onAnomaliesOnlyChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppLayout.mediumGap(context),
      runSpacing: AppLayout.smallGap(context),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search by fighter, label, or coordinates',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        DropdownButton<_TimeRange>(
          value: timeRange,
          items: _TimeRange.values
              .map(
                (value) => DropdownMenuItem<_TimeRange>(
                  value: value,
                  child: Text(value.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onTimeRangeChanged(value);
            }
          },
        ),
        DropdownButton<_SeverityFilter>(
          value: severityFilter,
          items: _SeverityFilter.values
              .map(
                (value) => DropdownMenuItem<_SeverityFilter>(
                  value: value,
                  child: Text(value.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onSeverityFilterChanged(value);
            }
          },
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: labelOnly,
              onChanged: (value) => onLabelOnlyChanged(value ?? false),
            ),
            const Text('Only labeled'),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: anomaliesOnly,
              onChanged: (value) => onAnomaliesOnlyChanged(value ?? false),
            ),
            const Text('Anomalies only'),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              SizedBox(height: AppLayout.smallGap(context)),
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final _CheckinSeverity severity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (severity) {
      _CheckinSeverity.good => (
          Colors.green.withValues(alpha: 0.15),
          Colors.green.shade700,
        ),
      _CheckinSeverity.warning => (
          Colors.orange.withValues(alpha: 0.18),
          Colors.orange.shade800,
        ),
      _CheckinSeverity.critical => (
          scheme.error.withValues(alpha: 0.15),
          scheme.error,
        ),
      _CheckinSeverity.info => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        severity.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _OperationsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppLayout.cardPadding(context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.6),
            scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Wrap(
        spacing: AppLayout.mediumGap(context),
        runSpacing: AppLayout.smallGap(context),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.monitor_heart_outlined, color: scheme.primary),
          Text(
            'Operational view: monitor GPS quality, investigate anomalies, and open coordinates in external maps.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AnomalyQueue extends StatelessWidget {
  const _AnomalyQueue({
    required this.anomalies,
    required this.onReviewAnomalies,
  });

  final List<_CheckinAnomaly> anomalies;
  final VoidCallback onReviewAnomalies;

  @override
  Widget build(BuildContext context) {
    final critical = anomalies
        .where((a) => a.severity == _CheckinSeverity.critical)
        .length;
    final warning = anomalies
        .where((a) => a.severity == _CheckinSeverity.warning)
        .length;
    final info = anomalies
        .where((a) => a.severity == _CheckinSeverity.info)
        .length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Anomaly Queue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onReviewAnomalies,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Review anomalies'),
                ),
              ],
            ),
            SizedBox(height: AppLayout.smallGap(context)),
            Wrap(
              spacing: AppLayout.smallGap(context),
              runSpacing: AppLayout.smallGap(context),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SeverityBadge(severity: _CheckinSeverity.critical),
                Text('$critical'),
                _SeverityBadge(severity: _CheckinSeverity.warning),
                Text('$warning'),
                _SeverityBadge(severity: _CheckinSeverity.info),
                Text('$info'),
              ],
            ),
            SizedBox(height: AppLayout.smallGap(context)),
            if (anomalies.isEmpty)
              const Text('No anomalies detected for selected range.')
            else
              SizedBox(
                height: 220,
                child: ListView.separated(
                  itemCount: math.min(anomalies.length, 8),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final anomaly = anomalies[index];
                    final timestamp =
                        anomaly.record.capturedAt ?? anomaly.record.createdAt;
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${anomaly.fighterName} - ${anomaly.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${anomaly.description}\n${timestamp == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toLocal())}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: SizedBox(
                        width: 160,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _SeverityBadge(severity: anomaly.severity),
                            IconButton(
                              tooltip: 'Open fighters',
                              onPressed: () => context.go(AppRoutes.fighters),
                              icon: const Icon(Icons.person_search_outlined),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GeoInsights {
  const _GeoInsights({
    required this.validCoordinatesCount,
    required this.invalidCoordinatesCount,
    required this.distinctGeoBuckets,
    required this.hotspotLabel,
    required this.hotspotCount,
  });

  final int validCoordinatesCount;
  final int invalidCoordinatesCount;
  final int distinctGeoBuckets;
  final String hotspotLabel;
  final int hotspotCount;

  factory _GeoInsights.fromRecords(List<CheckinRecord> records) {
    int valid = 0;
    int invalid = 0;
    final buckets = <String, int>{};

    for (final record in records) {
      final isValid = !(record.latitude == 0 && record.longitude == 0);
      if (isValid) {
        valid++;
      } else {
        invalid++;
      }
      final key =
          '${record.latitude.toStringAsFixed(2)},${record.longitude.toStringAsFixed(2)}';
      buckets.update(key, (value) => value + 1, ifAbsent: () => 1);
    }

    String hotspot = '-';
    int hotspotCount = 0;
    buckets.forEach((key, value) {
      if (value > hotspotCount) {
        hotspot = key;
        hotspotCount = value;
      }
    });

    return _GeoInsights(
      validCoordinatesCount: valid,
      invalidCoordinatesCount: invalid,
      distinctGeoBuckets: buckets.length,
      hotspotLabel: hotspot,
      hotspotCount: hotspotCount,
    );
  }
}

class _GeoInsightsCard extends StatelessWidget {
  const _GeoInsightsCard({required this.insights});

  final _GeoInsights insights;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
        child: Wrap(
          spacing: AppLayout.mediumGap(context),
          runSpacing: AppLayout.smallGap(context),
          children: [
            _MiniInsight(
              title: 'Valid coordinates',
              value: '${insights.validCoordinatesCount}',
            ),
            _MiniInsight(
              title: 'Invalid coordinates',
              value: '${insights.invalidCoordinatesCount}',
            ),
            _MiniInsight(
              title: 'Geo buckets (0.01deg)',
              value: '${insights.distinctGeoBuckets}',
            ),
            _MiniInsight(
              title: 'Top hotspot',
              value: '${insights.hotspotLabel} (${insights.hotspotCount})',
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInsight extends StatelessWidget {
  const _MiniInsight({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: AppLayout.smallGap(context)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.onCopyCsv});

  final VoidCallback onCopyCsv;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppLayout.mediumGap(context),
      runSpacing: AppLayout.smallGap(context),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporting',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Map links open externally (no embedded paid map API).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: onCopyCsv,
          icon: const Icon(Icons.table_view_outlined),
          label: const Text('Copy CSV'),
        ),
      ],
    );
  }
}

class _AnomalyFlag {
  const _AnomalyFlag({
    required this.severity,
    required this.title,
    required this.description,
  });

  final _CheckinSeverity severity;
  final String title;
  final String description;
}

class _CheckinAnomaly {
  const _CheckinAnomaly({
    required this.record,
    required this.fighterName,
    required this.severity,
    required this.title,
    required this.description,
  });

  final CheckinRecord record;
  final String fighterName;
  final _CheckinSeverity severity;
  final String title;
  final String description;
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.rowsPerPage,
    required this.rowsPerPageOptions,
    required this.startIndex,
    required this.endIndex,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.onRowsPerPageChanged,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int rowsPerPage;
  final List<int> rowsPerPageOptions;
  final int startIndex;
  final int endIndex;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onRowsPerPageChanged;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppLayout.smallGap(context)),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppLayout.mediumGap(context),
        runSpacing: AppLayout.smallGap(context),
        children: [
          DropdownButton<int>(
            value: rowsPerPage,
            onChanged: (value) {
              if (value != null) {
                onRowsPerPageChanged(value);
              }
            },
            items: rowsPerPageOptions
                .map(
                  (option) => DropdownMenuItem<int>(
                    value: option,
                    child: Text(option.toString()),
                  ),
                )
                .toList(),
          ),
          Text(totalCount == 0 ? '0' : '${startIndex + 1}-$endIndex / $totalCount'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${currentPage + 1}/$totalPages'),
              IconButton(
                onPressed: onNextPage,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppLayout.smallGap(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
