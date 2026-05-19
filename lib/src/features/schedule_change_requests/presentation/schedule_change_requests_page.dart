import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_layout.dart';
import '../../fighters/domain/fighter.dart';
import '../../fighters/presentation/fighters_controller.dart';
import '../../locations/presentation/locations_controller.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../whereabouts/domain/whereabouts_entry.dart';
import '../domain/schedule_change_request.dart';
import 'schedule_change_requests_controller.dart';

class ScheduleChangeRequestsPage extends ConsumerStatefulWidget {
  const ScheduleChangeRequestsPage({super.key});

  @override
  ConsumerState<ScheduleChangeRequestsPage> createState() =>
      _ScheduleChangeRequestsPageState();
}

class _ScheduleChangeRequestsPageState
    extends ConsumerState<ScheduleChangeRequestsPage> {
  static const List<int> _rowsPerPageOptions = [10, 20, 50];

  final TextEditingController _searchController = TextEditingController();
  _StatusFilter _statusFilter = _StatusFilter.pending;
  ScheduleChangeRequestType? _typeFilter;
  String? _fighterFilterId;
  _DateRangeFilter _dateRange = _DateRangeFilter.all;
  int _rowsPerPage = _rowsPerPageOptions.first;
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final requestsAsync = ref.watch(scheduleChangeRequestsStreamProvider);
    final fightersAsync = ref.watch(fightersStreamProvider);
    final mutation = ref.watch(scheduleChangeRequestMutationControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 980;

    ref.listen(scheduleChangeRequestMutationControllerProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
        ref.read(scheduleChangeRequestMutationControllerProvider.notifier).clearMessages();
      }
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
        ref.read(scheduleChangeRequestMutationControllerProvider.notifier).clearMessages();
      }
    });

    final fighters = fightersAsync.asData?.value ?? const <Fighter>[];
    final fighterNameById = {
      for (final fighter in fighters) fighter.uid: fighter.fullName,
    };
    final fighterById = {for (final fighter in fighters) fighter.uid: fighter};

    return Padding(
      padding: EdgeInsets.all(AppLayout.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('nav.scheduleRequests'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          Text(
            'Review fighter requests for schedule or testing location changes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: AppLayout.mediumGap(context)),
          Expanded(
            child: requestsAsync.when(
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
                child: Text('Could not load schedule change requests.'),
              ),
              data: (requests) {
                final pendingCount = requests
                    .where((r) => r.status == ScheduleChangeRequestStatus.pending)
                    .length;
                final filtered = _filterRequests(requests, fighterNameById);

                if (requests.isEmpty) {
                  return const Center(
                    child: Text('No schedule change requests yet.'),
                  );
                }

                if (filtered.isEmpty) {
                  return Column(
                    children: [
                      _PendingBanner(pendingCount: pendingCount),
                      SizedBox(height: AppLayout.mediumGap(context)),
                      _FiltersBar(
                        searchController: _searchController,
                        statusFilter: _statusFilter,
                        onStatusFilterChanged: (value) =>
                            setState(() {
                          _statusFilter = value;
                          _page = 0;
                        }),
                        typeFilter: _typeFilter,
                        onTypeFilterChanged: (value) =>
                            setState(() {
                          _typeFilter = value;
                          _page = 0;
                        }),
                        fighterFilterId: _fighterFilterId,
                        fighters: fighters,
                        onFighterFilterChanged: (value) =>
                            setState(() {
                          _fighterFilterId = value;
                          _page = 0;
                        }),
                        dateRange: _dateRange,
                        onDateRangeChanged: (value) =>
                            setState(() {
                          _dateRange = value;
                          _page = 0;
                        }),
                        onSearchChanged: (_) => setState(() => _page = 0),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text('No requests match current filters.'),
                        ),
                      ),
                    ],
                  );
                }

                final totalPages = math.max(
                  1,
                  (filtered.length / _rowsPerPage).ceil(),
                );
                final currentPage = _page.clamp(0, totalPages - 1).toInt();
                final startIndex = currentPage * _rowsPerPage;
                final endIndex = math.min(
                  startIndex + _rowsPerPage,
                  filtered.length,
                );
                final pageItems = filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    _PendingBanner(pendingCount: pendingCount),
                    SizedBox(height: AppLayout.mediumGap(context)),
                    _FiltersBar(
                      searchController: _searchController,
                      statusFilter: _statusFilter,
                      onStatusFilterChanged: (value) => setState(() {
                        _statusFilter = value;
                        _page = 0;
                      }),
                      typeFilter: _typeFilter,
                      onTypeFilterChanged: (value) => setState(() {
                        _typeFilter = value;
                        _page = 0;
                      }),
                      fighterFilterId: _fighterFilterId,
                      fighters: fighters,
                      onFighterFilterChanged: (value) => setState(() {
                        _fighterFilterId = value;
                        _page = 0;
                      }),
                      dateRange: _dateRange,
                      onDateRangeChanged: (value) => setState(() {
                        _dateRange = value;
                        _page = 0;
                      }),
                      onSearchChanged: (_) => setState(() => _page = 0),
                    ),
                    SizedBox(height: AppLayout.mediumGap(context)),
                    Expanded(
                      child: isNarrow
                          ? ListView.separated(
                              itemCount: pageItems.length,
                              separatorBuilder: (_, _) =>
                                  SizedBox(height: AppLayout.smallGap(context)),
                              itemBuilder: (context, index) {
                                final item = pageItems[index];
                                return _RequestCard(
                                  request: item,
                                  fighterName: fighterNameById[item.fighterId] ??
                                      item.fighterId,
                                  onTap: () => _openDetail(
                                    request: item,
                                    fighter: fighterById[item.fighterId],
                                  ),
                                );
                              },
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Fighter')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Submitted')),
                                  DataColumn(label: Text('Notes')),
                                  DataColumn(label: Text('Schedule')),
                                  DataColumn(label: Text('')),
                                ],
                                rows: pageItems.map((item) {
                                  final fighterName =
                                      fighterNameById[item.fighterId] ??
                                          item.fighterId;
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        SizedBox(
                                          width: 180,
                                          child: Text(
                                            fighterName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(item.requestTypeLabel)),
                                      DataCell(_StatusBadge(request: item)),
                                      DataCell(
                                        Text(_formatDate(item.createdAt)),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: Text(
                                            item.notesPreview,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item.schedulePreviewFromSnapshot() ??
                                              (item.scheduleId ?? '—'),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DataCell(
                                        TextButton(
                                          onPressed: mutation.isLoading
                                              ? null
                                              : () => _openDetail(
                                                    request: item,
                                                    fighter:
                                                        fighterById[item.fighterId],
                                                  ),
                                          child: const Text('Review'),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
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
                      onRowsPerPageChanged: (value) => setState(() {
                        _rowsPerPage = value;
                        _page = 0;
                      }),
                      onPreviousPage: currentPage == 0
                          ? null
                          : () => setState(() => _page = currentPage - 1),
                      onNextPage: currentPage >= totalPages - 1
                          ? null
                          : () => setState(() => _page = currentPage + 1),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<ScheduleChangeRequest> _filterRequests(
    List<ScheduleChangeRequest> items,
    Map<String, String> fighterNameById,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      if (!_statusFilter.matches(item.status)) {
        return false;
      }
      if (_typeFilter != null && item.requestType != _typeFilter) {
        return false;
      }
      if (_fighterFilterId != null &&
          _fighterFilterId!.isNotEmpty &&
          item.fighterId != _fighterFilterId) {
        return false;
      }
      if (!_dateRange.includes(item.createdAt)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final fighterName =
          (fighterNameById[item.fighterId] ?? item.fighterId).toLowerCase();
      return fighterName.contains(query) ||
          item.notes.toLowerCase().contains(query) ||
          item.requestTypeLabel.toLowerCase().contains(query);
    }).toList();
  }

  void _openDetail({
    required ScheduleChangeRequest request,
    required Fighter? fighter,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _RequestDetailDialog(
        request: request,
        fighter: fighter,
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }
}

enum _StatusFilter {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  all('All');

  const _StatusFilter(this.label);
  final String label;

  bool matches(ScheduleChangeRequestStatus? status) {
    switch (this) {
      case _StatusFilter.pending:
        return status == ScheduleChangeRequestStatus.pending;
      case _StatusFilter.approved:
        return status == ScheduleChangeRequestStatus.approved;
      case _StatusFilter.rejected:
        return status == ScheduleChangeRequestStatus.rejected;
      case _StatusFilter.all:
        return true;
    }
  }
}

enum _DateRangeFilter {
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  all('All time');

  const _DateRangeFilter(this.label);
  final String label;

  bool includes(DateTime? createdAt) {
    if (createdAt == null) {
      return this == _DateRangeFilter.all;
    }
    final now = DateTime.now();
    switch (this) {
      case _DateRangeFilter.last7Days:
        return createdAt.isAfter(now.subtract(const Duration(days: 7)));
      case _DateRangeFilter.last30Days:
        return createdAt.isAfter(now.subtract(const Duration(days: 30)));
      case _DateRangeFilter.all:
        return true;
    }
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppLayout.cardPadding(context)),
      decoration: BoxDecoration(
        color: pendingCount > 0
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            pendingCount > 0 ? Icons.pending_actions : Icons.check_circle_outline,
            color: scheme.primary,
          ),
          SizedBox(width: AppLayout.smallGap(context)),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? '$pendingCount pending request${pendingCount == 1 ? '' : 's'} need review.'
                  : 'No pending requests — you are caught up.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.fighterFilterId,
    required this.fighters,
    required this.onFighterFilterChanged,
    required this.dateRange,
    required this.onDateRangeChanged,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final _StatusFilter statusFilter;
  final ValueChanged<_StatusFilter> onStatusFilterChanged;
  final ScheduleChangeRequestType? typeFilter;
  final ValueChanged<ScheduleChangeRequestType?> onTypeFilterChanged;
  final String? fighterFilterId;
  final List<Fighter> fighters;
  final ValueChanged<String?> onFighterFilterChanged;
  final _DateRangeFilter dateRange;
  final ValueChanged<_DateRangeFilter> onDateRangeChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppLayout.mediumGap(context),
      runSpacing: AppLayout.smallGap(context),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search fighter or notes',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        DropdownButton<_StatusFilter>(
          value: statusFilter,
          items: _StatusFilter.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onStatusFilterChanged(value);
            }
          },
        ),
        DropdownButton<ScheduleChangeRequestType?>(
          value: typeFilter,
          hint: const Text('All types'),
          items: [
            const DropdownMenuItem<ScheduleChangeRequestType?>(
              value: null,
              child: Text('All types'),
            ),
            ...ScheduleChangeRequestType.values.map(
              (type) => DropdownMenuItem(
                value: type,
                child: Text(type.label),
              ),
            ),
          ],
          onChanged: onTypeFilterChanged,
        ),
        DropdownButton<String?>(
          value: fighterFilterId,
          hint: const Text('All fighters'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All fighters'),
            ),
            ...fighters.map(
              (fighter) => DropdownMenuItem(
                value: fighter.uid,
                child: Text(fighter.fullName),
              ),
            ),
          ],
          onChanged: onFighterFilterChanged,
        ),
        DropdownButton<_DateRangeFilter>(
          value: dateRange,
          items: _DateRangeFilter.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onDateRangeChanged(value);
            }
          },
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.fighterName,
    required this.onTap,
  });

  final ScheduleChangeRequest request;
  final String fighterName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(fighterName),
        subtitle: Text(
          '${request.requestTypeLabel} • ${_formatDate(request.createdAt)}\n'
          '${request.notesPreview}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: _StatusBadge(request: request),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.request});

  final ScheduleChangeRequest request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (request.status) {
      ScheduleChangeRequestStatus.pending => (
          Colors.orange.withValues(alpha: 0.18),
          Colors.orange.shade900,
        ),
      ScheduleChangeRequestStatus.approved => (
          Colors.green.withValues(alpha: 0.15),
          Colors.green.shade800,
        ),
      ScheduleChangeRequestStatus.rejected => (
          scheme.error.withValues(alpha: 0.15),
          scheme.error,
        ),
      _ => (
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
        request.statusLabel,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RequestDetailDialog extends ConsumerStatefulWidget {
  const _RequestDetailDialog({
    required this.request,
    required this.fighter,
  });

  final ScheduleChangeRequest request;
  final Fighter? fighter;

  @override
  ConsumerState<_RequestDetailDialog> createState() =>
      _RequestDetailDialogState();
}

class _RequestDetailDialogState extends ConsumerState<_RequestDetailDialog> {
  final TextEditingController _adminNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.request.adminNotes?.trim() ?? '';
    if (existing.isNotEmpty) {
      _adminNotesController.text = existing;
    }
  }

  @override
  void dispose() {
    _adminNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final fighter = widget.fighter;
    final mutation = ref.watch(scheduleChangeRequestMutationControllerProvider);
    final scheduleId = request.scheduleId?.trim() ?? '';
    final liveScheduleAsync = scheduleId.isEmpty
        ? const AsyncValue<WhereaboutsEntry?>.data(null)
        : ref.watch(scheduleByIdProvider(scheduleId));
    final locations = ref.watch(locationsStreamProvider).asData?.value ?? [];
    final contacts = ref.watch(contactsStreamProvider).asData?.value ?? [];
    final locationNameById = {for (final loc in locations) loc.id: loc.name};
    final contactNameById = {for (final c in contacts) c.id: c.name};

    final canAct = request.isPending && !mutation.isLoading;
    final proposedText = readScheduleField(
      request.requestedChanges,
      const ['proposedLocationText'],
    );

    return AlertDialog(
      title: Text('${request.requestTypeLabel} • ${request.statusLabel}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fighter',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              _DetailRow(
                label: 'Name',
                value: fighter?.fullName ?? request.fighterId,
              ),
              _DetailRow(label: 'Email', value: fighter?.email ?? '—'),
              _DetailRow(label: 'Phone', value: fighter?.phone ?? '—'),
              SizedBox(height: AppLayout.mediumGap(context)),
              Text(
                'Request',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              _DetailRow(
                label: 'Submitted',
                value: _formatDate(request.createdAt),
              ),
              _DetailRow(label: 'Fighter notes', value: request.notes.trim().isEmpty ? '—' : request.notes),
              if (request.reviewedAt != null) ...[
                _DetailRow(
                  label: 'Reviewed',
                  value: _formatDate(request.reviewedAt),
                ),
                _DetailRow(
                  label: 'Reviewed by',
                  value: request.reviewedBy ?? '—',
                ),
              ],
              SizedBox(height: AppLayout.mediumGap(context)),
              _ScheduleSection(
                title: 'Current schedule',
                snapshot: request.currentSnapshot,
                liveSchedule: liveScheduleAsync.asData?.value,
                locationNameById: locationNameById,
                contactNameById: contactNameById,
              ),
              SizedBox(height: AppLayout.mediumGap(context)),
              _ChangeComparisonSection(
                currentSnapshot: request.currentSnapshot,
                requestedChanges: request.requestedChanges,
                liveSchedule: liveScheduleAsync.asData?.value,
                locationNameById: locationNameById,
                proposedLocationText: proposedText,
              ),
              if (proposedText.isNotEmpty) ...[
                SizedBox(height: AppLayout.mediumGap(context)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .tertiaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proposed location (not in directory)',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      Text(proposedText),
                    ],
                  ),
                ),
              ],
              if (request.isPending) ...[
                SizedBox(height: AppLayout.mediumGap(context)),
                TextField(
                  controller: _adminNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Admin notes (shown to fighter)',
                    alignLabelWithHint: true,
                  ),
                ),
              ] else if ((request.adminNotes ?? '').trim().isNotEmpty) ...[
                SizedBox(height: AppLayout.mediumGap(context)),
                _DetailRow(
                  label: 'Admin notes',
                  value: request.adminNotes!,
                ),
              ],
              if (scheduleId.isNotEmpty &&
                  request.isPending &&
                  hasScheduleApplyFields(request.requestedChanges)) ...[
                SizedBox(height: AppLayout.smallGap(context)),
                Text(
                  'Approving will update schedule $scheduleId with the requested fields.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: mutation.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (canAct) ...[
          TextButton(
            onPressed: () => _reject(request),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () => _approve(request),
            child: mutation.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Approve'),
          ),
        ],
      ],
    );
  }

  Future<void> _approve(ScheduleChangeRequest request) async {
    await ref
        .read(scheduleChangeRequestMutationControllerProvider.notifier)
        .approve(request: request, adminNotes: _adminNotesController.text);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _reject(ScheduleChangeRequest request) async {
    final notes = _adminNotesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add admin notes explaining the rejection.'),
        ),
      );
      return;
    }
    await ref
        .read(scheduleChangeRequestMutationControllerProvider.notifier)
        .reject(request: request, adminNotes: notes);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.title,
    required this.snapshot,
    required this.liveSchedule,
    required this.locationNameById,
    required this.contactNameById,
  });

  final String title;
  final Map<String, dynamic> snapshot;
  final WhereaboutsEntry? liveSchedule;
  final Map<String, String> locationNameById;
  final Map<String, String> contactNameById;

  @override
  Widget build(BuildContext context) {
    final fields = _resolveScheduleFields(
      snapshot: snapshot,
      entry: liveSchedule,
      locationNameById: locationNameById,
      contactNameById: contactNameById,
    );
    if (fields.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: AppLayout.smallGap(context)),
          const Text('No schedule context available.'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (liveSchedule != null)
          Padding(
            padding: EdgeInsets.only(bottom: AppLayout.smallGap(context)),
            child: Text(
              'Live schedule loaded',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        SizedBox(height: AppLayout.smallGap(context)),
        ...fields.entries.map(
          (e) => _DetailRow(label: e.key, value: e.value),
        ),
      ],
    );
  }
}

class _ChangeComparisonSection extends StatelessWidget {
  const _ChangeComparisonSection({
    required this.currentSnapshot,
    required this.requestedChanges,
    required this.liveSchedule,
    required this.locationNameById,
    required this.proposedLocationText,
  });

  final Map<String, dynamic> currentSnapshot;
  final Map<String, dynamic> requestedChanges;
  final WhereaboutsEntry? liveSchedule;
  final Map<String, String> locationNameById;
  final String proposedLocationText;

  @override
  Widget build(BuildContext context) {
    final rows = <_CompareRow>[];
    void addRow(String label, String currentKey, List<String> requestKeys) {
      final currentFields = _resolveScheduleFields(
        snapshot: currentSnapshot,
        entry: liveSchedule,
        locationNameById: locationNameById,
        contactNameById: const {},
      );
      var current = currentFields[label] ?? '—';
      var requested = '—';
      for (final key in requestKeys) {
        final value = requestedChanges[key];
        if (value == null) {
          continue;
        }
        requested = formatTimestampField(value);
        if (requested != '—') {
          break;
        }
      }
      if (requested == '—') {
        final fromMap = readScheduleField(requestedChanges, requestKeys);
        if (fromMap.isNotEmpty) {
          requested = fromMap;
        }
      }
      if (label == 'Location' && proposedLocationText.isNotEmpty) {
        requested = proposedLocationText;
      }
      if (current != requested) {
        rows.add(_CompareRow(label: label, current: current, requested: requested));
      }
    }

    addRow('Date', 'Date', const ['date', 'scheduleDate', 'startAt']);
    addRow('Start time', 'Start', const ['startTime', 'startAt']);
    addRow('End time', 'End', const ['endTime', 'endAt']);
    addRow('Location', 'Location', const ['locationName', 'locationId']);

    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requested changes',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          const Text('No comparable fields in this request.'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current → requested',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: AppLayout.smallGap(context)),
        ...rows.map(
          (row) => Padding(
            padding: EdgeInsets.only(bottom: AppLayout.smallGap(context)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Expanded(
                  child: Text('${row.current} → ${row.requested}'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareRow {
  const _CompareRow({
    required this.label,
    required this.current,
    required this.requested,
  });

  final String label;
  final String current;
  final String requested;
}

Map<String, String> _resolveScheduleFields({
  required Map<String, dynamic> snapshot,
  required WhereaboutsEntry? entry,
  required Map<String, String> locationNameById,
  required Map<String, String> contactNameById,
}) {
  final result = <String, String>{};
  if (entry != null) {
    result['Date'] = entry.date;
    result['Start'] = entry.startTime;
    result['End'] = entry.endTime;
    final locName = entry.locationName.isNotEmpty
        ? entry.locationName
        : (locationNameById[entry.locationId] ?? entry.locationId);
    result['Location'] = locName;
    final contactName = contactNameById[entry.contactId];
    result['Contact'] = contactName ?? entry.contactId;
    result['Recurrence'] = entry.recurrence;
    if (entry.notes.trim().isNotEmpty) {
      result['Notes'] = entry.notes;
    }
    return result;
  }
  if (snapshot.isEmpty) {
    return result;
  }
  final date = readScheduleField(snapshot, const ['date', 'scheduleDate']);
  if (date.isNotEmpty) {
    result['Date'] = date;
  }
  final start = readScheduleField(snapshot, const ['startTime', 'fromTime']);
  if (start.isNotEmpty) {
    result['Start'] = start;
  }
  final end = readScheduleField(snapshot, const ['endTime', 'toTime']);
  if (end.isNotEmpty) {
    result['End'] = end;
  }
  final location = readScheduleField(snapshot, const [
    'locationName',
    'location',
  ]);
  if (location.isNotEmpty) {
    result['Location'] = location;
  }
  final contact = readScheduleField(snapshot, const ['contactName', 'contact']);
  if (contact.isNotEmpty) {
    result['Contact'] = contact;
  }
  final recurrence = readScheduleField(snapshot, const ['recurrence', 'frequency']);
  if (recurrence.isNotEmpty) {
    result['Recurrence'] = recurrence;
  }
  final notes = readScheduleField(snapshot, const ['notes']);
  if (notes.isNotEmpty) {
    result['Notes'] = notes;
  }
  return result;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
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
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppLayout.mediumGap(context),
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
    );
  }
}
