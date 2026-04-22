import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../contacts/domain/contact.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../fighters/domain/fighter.dart';
import '../../fighters/presentation/fighters_controller.dart';
import '../../locations/domain/location_record.dart';
import '../../locations/presentation/locations_controller.dart';
import '../domain/whereabouts_entry.dart';
import 'whereabouts_controller.dart';

class WhereaboutsPage extends ConsumerStatefulWidget {
  const WhereaboutsPage({super.key});

  @override
  ConsumerState<WhereaboutsPage> createState() => _WhereaboutsPageState();
}

class _WhereaboutsPageState extends ConsumerState<WhereaboutsPage> {
  static const List<int> _rowsPerPageOptions = [10, 20, 50];
  final TextEditingController _searchController = TextEditingController();
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
    final mutation = ref.watch(whereaboutsMutationControllerProvider);
    final errorMessage = mutation.errorMessage;
    final successMessage = mutation.successMessage;
    final whereaboutsAsync = ref.watch(whereaboutsStreamProvider);
    final fightersAsync = ref.watch(fightersStreamProvider);
    final contactsAsync = ref.watch(contactsStreamProvider);
    final locationsAsync = ref.watch(locationsStreamProvider);
    final fighterNames = {
      for (final fighter in fightersAsync.asData?.value ?? const <Fighter>[])
        fighter.uid: fighter.fullName,
    };
    final contactNames = {
      for (final contact in contactsAsync.asData?.value ?? const <Contact>[])
        contact.id: contact.name,
    };
    final locationNames = {
      for (final location
          in locationsAsync.asData?.value ?? const <LocationRecord>[])
        location.id: location.name,
    };
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 980;

    return Padding(
      padding: EdgeInsets.all(AppLayout.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNarrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.tr('whereabouts.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                // TODO(phase-3): Re-enable admin "Add Whereabouts Entry" action
                // once scope confirms admin create is required.
              ],
            )
          else
            Row(
              children: [
                Text(
                  loc.tr('whereabouts.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                // TODO(phase-3): Re-enable admin "Add Whereabouts Entry" action
                // once scope confirms admin create is required.
              ],
            ),
          if (errorMessage != null)
            _MutationBanner(message: loc.tr(errorMessage), isError: true),
          if (successMessage != null)
            _MutationBanner(message: loc.tr(successMessage), isError: false),
          SizedBox(height: AppLayout.mediumGap(context)),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() => _page = 0),
            decoration: InputDecoration(
              labelText: loc.tr('whereabouts.search'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
          SizedBox(height: AppLayout.mediumGap(context)),
          Expanded(
            child: whereaboutsAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: AppLayout.smallGap(context)),
                    Text(loc.tr('whereabouts.loading')),
                  ],
                ),
              ),
              error: (error, _) => Center(
                child: Text('${loc.tr('whereabouts.error')}\n$error'),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(child: Text(loc.tr('whereabouts.empty')));
                }
                final filtered = _filterItems(
                  items: items,
                  fighterNames: fighterNames,
                  contactNames: contactNames,
                  locationNames: locationNames,
                );
                if (filtered.isEmpty) {
                  return Center(child: Text(loc.tr('whereabouts.noResults')));
                }
                final totalPages =
                    math.max(1, (filtered.length / _rowsPerPage).ceil());
                final currentPage = _page.clamp(0, totalPages - 1).toInt();
                final startIndex =
                    filtered.isEmpty ? 0 : currentPage * _rowsPerPage;
                final endIndex = filtered.isEmpty
                    ? 0
                    : math.min(startIndex + _rowsPerPage, filtered.length);
                final pageItems = filtered.isEmpty
                    ? const <WhereaboutsEntry>[]
                    : filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: isNarrow
                          ? ListView.separated(
                              itemCount: pageItems.length,
                              separatorBuilder: (_, _) =>
                                  SizedBox(height: AppLayout.smallGap(context)),
                              itemBuilder: (context, index) {
                                final item = pageItems[index];
                                final fighterName =
                                    fighterNames[item.fighterId] ??
                                        loc.tr('whereabouts.na');
                                final locationName =
                                    locationNames[item.locationId] ??
                                        loc.tr('whereabouts.na');
                                final contactName =
                                    contactNames[item.contactId] ??
                                        loc.tr('whereabouts.na');
                                return Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                      AppLayout.cardPadding(context),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '$fighterName - ${item.date}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  loc.tr('whereabouts.edit'),
                                              onPressed: () => _openEditDialog(
                                                item: item,
                                                fighters: fightersAsync
                                                        .asData?.value ??
                                                    const [],
                                                contacts: contactsAsync
                                                        .asData?.value ??
                                                    const <Contact>[],
                                                locations: locationsAsync
                                                        .asData?.value ??
                                                    const <LocationRecord>[],
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                            '${item.startTime} - ${item.endTime}'),
                                        Text(locationName),
                                        Text(contactName),
                                        SizedBox(
                                          height: AppLayout.smallGap(context),
                                        ),
                                        Chip(
                                          label: Text(
                                            loc.tr(
                                              _recurrenceLabelKey(
                                                  item.recurrence),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                columns: [
                                  DataColumn(
                                    label: Text(loc.tr('whereabouts.fighter')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('whereabouts.date')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('whereabouts.time')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('whereabouts.location')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('whereabouts.contact')),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      loc.tr('whereabouts.recurrence'),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('whereabouts.actions')),
                                  ),
                                ],
                                rows: pageItems.map((item) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          fighterNames[item.fighterId] ??
                                              loc.tr('whereabouts.na'),
                                        ),
                                      ),
                                      DataCell(Text(item.date)),
                                      DataCell(
                                        Text(
                                            '${item.startTime} - ${item.endTime}'),
                                      ),
                                      DataCell(
                                        Text(
                                          locationNames[item.locationId] ??
                                              loc.tr('whereabouts.na'),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          contactNames[item.contactId] ??
                                              loc.tr('whereabouts.na'),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          loc.tr(
                                            _recurrenceLabelKey(
                                                item.recurrence),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          tooltip: loc.tr('whereabouts.edit'),
                                          onPressed: () => _openEditDialog(
                                            item: item,
                                            fighters:
                                                fightersAsync.asData?.value ??
                                                    const [],
                                            contacts:
                                                contactsAsync.asData?.value ??
                                                    const <Contact>[],
                                            locations:
                                                locationsAsync.asData?.value ??
                                                    const <LocationRecord>[],
                                          ),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    SizedBox(height: AppLayout.smallGap(context)),
                    _WhereaboutsPagination(
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
                              setState(() {
                                _page = currentPage - 1;
                              });
                            },
                      onNextPage: currentPage >= totalPages - 1
                          ? null
                          : () {
                              setState(() {
                                _page = currentPage + 1;
                              });
                            },
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

  List<WhereaboutsEntry> _filterItems({
    required List<WhereaboutsEntry> items,
    required Map<String, String> fighterNames,
    required Map<String, String> contactNames,
    required Map<String, String> locationNames,
  }) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    return items.where((item) {
      final fighter = fighterNames[item.fighterId] ?? '';
      final contact = contactNames[item.contactId] ?? '';
      final location = locationNames[item.locationId] ?? '';
      return fighter.toLowerCase().contains(query) ||
          contact.toLowerCase().contains(query) ||
          location.toLowerCase().contains(query) ||
          item.date.toLowerCase().contains(query) ||
          item.startTime.toLowerCase().contains(query) ||
          item.endTime.toLowerCase().contains(query) ||
          item.notes.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openEditDialog({
    required WhereaboutsEntry item,
    required List<Fighter> fighters,
    required List<Contact> contacts,
    required List<LocationRecord> locations,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _WhereaboutsDialog(
        item: item,
        fighters: fighters,
        contacts: contacts,
        locations: locations,
      ),
    );
    if (mounted) {
      ref.read(whereaboutsMutationControllerProvider.notifier).clearMessages();
    }
  }
}

class _WhereaboutsPagination extends StatelessWidget {
  const _WhereaboutsPagination({
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
          Text(
            totalCount == 0 ? '0' : '${startIndex + 1}-$endIndex / $totalCount',
          ),
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

class _WhereaboutsDialog extends ConsumerStatefulWidget {
  const _WhereaboutsDialog({
    this.item,
    required this.fighters,
    required this.contacts,
    required this.locations,
  });

  final WhereaboutsEntry? item;
  final List<Fighter> fighters;
  final List<Contact> contacts;
  final List<LocationRecord> locations;

  @override
  ConsumerState<_WhereaboutsDialog> createState() => _WhereaboutsDialogState();
}

class _WhereaboutsDialogState extends ConsumerState<_WhereaboutsDialog> {
  static const List<String> _recurrenceOptions = ['daily', 'weekly', 'monthly'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _notesController;
  late String _fighterId;
  late String _locationId;
  late String _contactId;
  late String _recurrence;

  bool get isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _dateController = TextEditingController(text: item?.date ?? '');
    _startTimeController = TextEditingController(text: item?.startTime ?? '');
    _endTimeController = TextEditingController(text: item?.endTime ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    _fighterId = item?.fighterId ?? _firstFighterId(widget.fighters);
    _locationId = item?.locationId ?? _firstLocationId(widget.locations);
    _contactId = item?.contactId ?? _firstContactId(widget.contacts);
    _recurrence = item?.recurrence ?? _recurrenceOptions.first;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final mutation = ref.watch(whereaboutsMutationControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth =
        width < 760 ? width * 0.9 : AppLayout.kpiCardWidth(context) * 3;

    return AlertDialog(
      title: Text(loc.tr(isEdit ? 'whereabouts.edit' : 'whereabouts.add')),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFighterDropdown(loc),
                SizedBox(height: AppLayout.smallGap(context)),
                _buildLocationDropdown(loc),
                SizedBox(height: AppLayout.smallGap(context)),
                _buildContactDropdown(loc),
                SizedBox(height: AppLayout.smallGap(context)),
                _buildDateField(loc),
                SizedBox(height: AppLayout.smallGap(context)),
                Row(
                  children: [
                    Expanded(child: _buildTimeField(loc, isStart: true)),
                    SizedBox(width: AppLayout.smallGap(context)),
                    Expanded(child: _buildTimeField(loc, isStart: false)),
                  ],
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                DropdownButtonFormField<String>(
                  initialValue: normalizeRecurrence(_recurrence),
                  decoration: InputDecoration(
                    labelText: loc.tr('whereabouts.recurrence'),
                    border: const OutlineInputBorder(),
                  ),
                  items: _recurrenceOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(loc.tr(_recurrenceLabelKey(value))),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _recurrence = value;
                      });
                    }
                  },
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: loc.tr('whereabouts.notes'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: mutation.isLoading ? null : () => Navigator.pop(context),
          child: Text(loc.tr('fighters.cancel')),
        ),
        FilledButton(
          onPressed: mutation.isLoading
              ? null
              : () async {
                  final formState = _formKey.currentState;
                  if (formState == null || !formState.validate()) {
                    return;
                  }
                  if (!_isTimeRangeValid(
                    _startTimeController.text,
                    _endTimeController.text,
                  )) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(loc.tr('whereabouts.invalidTime'))),
                    );
                    return;
                  }

                  final notifier = ref.read(
                    whereaboutsMutationControllerProvider.notifier,
                  );
                  if (isEdit) {
                    final item = widget.item;
                    if (item == null) {
                      return;
                    }
                    await notifier.update(
                      id: item.id,
                      fighterId: _fighterId,
                      date: _dateController.text,
                      startTime: _startTimeController.text,
                      endTime: _endTimeController.text,
                      locationId: _locationId,
                      contactId: _contactId,
                      notes: _notesController.text,
                      recurrence: _recurrence,
                    );
                  } else {
                    await notifier.create(
                      fighterId: _fighterId,
                      date: _dateController.text,
                      startTime: _startTimeController.text,
                      endTime: _endTimeController.text,
                      locationId: _locationId,
                      contactId: _contactId,
                      notes: _notesController.text,
                      recurrence: _recurrence,
                    );
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: Text(
            mutation.isLoading
                ? loc.tr('common.loading')
                : loc.tr('fighters.save'),
          ),
        ),
      ],
    );
  }

  Widget _buildFighterDropdown(dynamic loc) {
    final options = widget.fighters;
    return DropdownButtonFormField<String>(
      initialValue: _safeInitial(
        current: _fighterId,
        options: options.map((item) => item.uid),
      ),
      decoration: InputDecoration(
        labelText: loc.tr('whereabouts.fighter'),
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (fighter) => DropdownMenuItem(
              value: fighter.uid,
              child: Text(fighter.fullName),
            ),
          )
          .toList(),
      onChanged: options.isEmpty
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  _fighterId = value;
                });
              }
            },
      validator: (_) {
        if (_fighterId.isEmpty) {
          return context.l10n.tr('fighters.required');
        }
        return null;
      },
    );
  }

  Widget _buildLocationDropdown(dynamic loc) {
    final options = widget.locations;
    return DropdownButtonFormField<String>(
      initialValue: _safeInitial(
        current: _locationId,
        options: options.map((item) => item.id),
      ),
      decoration: InputDecoration(
        labelText: loc.tr('whereabouts.location'),
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (item) => DropdownMenuItem(
              value: item.id,
              child: Text(item.name),
            ),
          )
          .toList(),
      onChanged: options.isEmpty
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  _locationId = value;
                });
              }
            },
      validator: (_) {
        if (_locationId.isEmpty) {
          return context.l10n.tr('fighters.required');
        }
        return null;
      },
    );
  }

  Widget _buildContactDropdown(dynamic loc) {
    final options = widget.contacts;
    return DropdownButtonFormField<String>(
      initialValue: _safeInitial(
        current: _contactId,
        options: options.map((item) => item.id),
      ),
      decoration: InputDecoration(
        labelText: loc.tr('whereabouts.contact'),
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (item) => DropdownMenuItem(
              value: item.id,
              child: Text(item.name),
            ),
          )
          .toList(),
      onChanged: options.isEmpty
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  _contactId = value;
                });
              }
            },
      validator: (_) {
        if (_contactId.isEmpty) {
          return context.l10n.tr('fighters.required');
        }
        return null;
      },
    );
  }

  Widget _buildDateField(dynamic loc) {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: loc.tr('whereabouts.date'),
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onTap: _pickDate,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.l10n.tr('fighters.required');
        }
        return null;
      },
    );
  }

  Widget _buildTimeField(dynamic loc, {required bool isStart}) {
    final controller = isStart ? _startTimeController : _endTimeController;
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText:
            loc.tr(isStart ? 'whereabouts.startTime' : 'whereabouts.endTime'),
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time),
      ),
      onTap: () => _pickTime(controller),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.l10n.tr('fighters.required');
        }
        return null;
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _parseDate(_dateController.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      final month = picked.month.toString().padLeft(2, '0');
      final day = picked.day.toString().padLeft(2, '0');
      _dateController.text = '${picked.year}-$month-$day';
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final parsed = _parseTime(controller.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: parsed ?? now,
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
    }
  }
}

class _MutationBanner extends StatelessWidget {
  const _MutationBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? Theme.of(context).colorScheme.error : AppColors.success;
    final bgColor = isError
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
        : AppColors.success.withValues(alpha: 0.08);
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;
    return Padding(
      padding: EdgeInsets.only(top: AppLayout.smallGap(context)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppLayout.mediumGap(context)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: AppLayout.smallGap(context)),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _recurrenceLabelKey(String value) {
  switch (normalizeRecurrence(value)) {
    case 'weekly':
      return 'whereabouts.weekly';
    case 'monthly':
      return 'whereabouts.monthly';
    default:
      return 'whereabouts.daily';
  }
}

String _firstFighterId(List<Fighter> items) =>
    items.isEmpty ? '' : items.first.uid;

String _firstContactId(List<Contact> items) =>
    items.isEmpty ? '' : items.first.id;

String _firstLocationId(List<LocationRecord> items) =>
    items.isEmpty ? '' : items.first.id;

String? _safeInitial({
  required String current,
  required Iterable<String> options,
}) {
  if (current.isEmpty) {
    return null;
  }
  final optionSet = options.toSet();
  return optionSet.contains(current) ? current : null;
}

DateTime? _parseDate(String raw) {
  final parts = raw.split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

TimeOfDay? _parseTime(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

bool _isTimeRangeValid(String start, String end) {
  final startTime = _parseTime(start);
  final endTime = _parseTime(end);
  if (startTime == null || endTime == null) {
    return false;
  }
  final startMinutes = startTime.hour * 60 + startTime.minute;
  final endMinutes = endTime.hour * 60 + endTime.minute;
  return endMinutes > startMinutes;
}
