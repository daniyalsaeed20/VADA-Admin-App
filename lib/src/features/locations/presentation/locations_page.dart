import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../fighters/domain/fighter.dart';
import '../../fighters/presentation/fighters_controller.dart';
import '../domain/location_record.dart';
import 'locations_controller.dart';

class LocationsPage extends ConsumerStatefulWidget {
  const LocationsPage({super.key});

  @override
  ConsumerState<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends ConsumerState<LocationsPage> {
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
    final locationsAsync = ref.watch(locationsStreamProvider);
    final fightersAsync = ref.watch(fightersStreamProvider);
    final mutation = ref.watch(locationMutationControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 900;
    final fighters = fightersAsync.asData?.value ?? const <Fighter>[];
    final fighterNameById = {
      for (final fighter in fighters) fighter.uid: fighter.fullName,
    };

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
                  loc.tr('locations.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                FilledButton.icon(
                  onPressed: () => _openCreateDialog(fighters),
                  icon: const Icon(Icons.add),
                  label: Text(loc.tr('locations.add')),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  loc.tr('locations.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openCreateDialog(fighters),
                  icon: const Icon(Icons.add),
                  label: Text(loc.tr('locations.add')),
                ),
              ],
            ),
          if (mutation.errorMessage != null)
            _MutationBanner(
                message: loc.tr(mutation.errorMessage!), isError: true),
          if (mutation.successMessage != null)
            _MutationBanner(
              message: loc.tr(mutation.successMessage!),
              isError: false,
            ),
          SizedBox(height: AppLayout.mediumGap(context)),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: loc.tr('locations.search'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (_) => setState(() => _page = 0),
          ),
          SizedBox(height: AppLayout.mediumGap(context)),
          Expanded(
            child: locationsAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: AppLayout.smallGap(context)),
                    Text(loc.tr('locations.loading')),
                  ],
                ),
              ),
              error: (_, _) => Center(child: Text(loc.tr('locations.error'))),
              data: (locations) {
                final filtered = _filterLocations(locations, fighterNameById);
                if (locations.isEmpty) {
                  return Center(child: Text(loc.tr('locations.empty')));
                }
                if (filtered.isEmpty) {
                  return Center(child: Text(loc.tr('locations.noResults')));
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
                    ? const <LocationRecord>[]
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
                                final assigneeLabels = _assigneeLabels(
                                  item: item,
                                  fighterNameById: fighterNameById,
                                  loc: loc,
                                );
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
                                                item.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: loc.tr('locations.edit'),
                                              onPressed: () => _openEditDialog(
                                                  item, fighters),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(item.address),
                                        SizedBox(
                                          height: AppLayout.smallGap(context),
                                        ),
                                        Chip(
                                          label: Text(
                                            loc.tr(_locationTypeLabelKey(
                                                item.type)),
                                          ),
                                        ),
                                        SizedBox(
                                          height: AppLayout.smallGap(context),
                                        ),
                                        Wrap(
                                          spacing: AppLayout.smallGap(context),
                                          runSpacing:
                                              AppLayout.smallGap(context),
                                          children: assigneeLabels
                                              .map((name) =>
                                                  Chip(label: Text(name)))
                                              .toList(),
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
                                    label: Text(loc.tr('locations.name')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('locations.address')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('locations.type')),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      loc.tr('locations.assignedFighters'),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('locations.actions')),
                                  ),
                                ],
                                rows: pageItems.map((item) {
                                  final assigneeLabels = _assigneeLabels(
                                    item: item,
                                    fighterNameById: fighterNameById,
                                    loc: loc,
                                  );
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(item.name)),
                                      DataCell(
                                        SizedBox(
                                          width: 230,
                                          child: Text(
                                            item.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(loc.tr(
                                            _locationTypeLabelKey(item.type))),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 240,
                                          child: Text(
                                            assigneeLabels.join(', '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          tooltip: loc.tr('locations.edit'),
                                          onPressed: () =>
                                              _openEditDialog(item, fighters),
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
                    _LocationsPagination(
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

  List<LocationRecord> _filterLocations(
    List<LocationRecord> locations,
    Map<String, String> fighterNameById,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return locations;
    }
    return locations.where((item) {
      final assignees = item.assignedFighterIds
          .map((id) => fighterNameById[id]?.toLowerCase() ?? '')
          .join(' ');
      return item.name.toLowerCase().contains(query) ||
          item.address.toLowerCase().contains(query) ||
          item.type.toLowerCase().contains(query) ||
          assignees.contains(query);
    }).toList();
  }

  List<String> _assigneeLabels({
    required LocationRecord item,
    required Map<String, String> fighterNameById,
    required dynamic loc,
  }) {
    if (item.assignedFighterIds.isEmpty) {
      return [loc.tr('locations.unassigned')];
    }
    return item.assignedFighterIds
        .map((id) => fighterNameById[id] ?? id)
        .toList();
  }

  Future<void> _openCreateDialog(List<Fighter> fighters) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LocationDialog(fighters: fighters),
    );
    if (mounted) {
      ref.read(locationMutationControllerProvider.notifier).clearMessages();
    }
  }

  Future<void> _openEditDialog(
      LocationRecord item, List<Fighter> fighters) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LocationDialog(location: item, fighters: fighters),
    );
    if (mounted) {
      ref.read(locationMutationControllerProvider.notifier).clearMessages();
    }
  }
}

class _LocationsPagination extends StatelessWidget {
  const _LocationsPagination({
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

class _LocationDialog extends ConsumerStatefulWidget {
  const _LocationDialog({this.location, required this.fighters});

  final LocationRecord? location;
  final List<Fighter> fighters;

  @override
  ConsumerState<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends ConsumerState<_LocationDialog> {
  static const List<String> _types = ['testing', 'training', 'event'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late String _selectedType;
  late Set<String> _assignedFighterIds;

  bool get isEdit => widget.location != null;

  @override
  void initState() {
    super.initState();
    final item = widget.location;
    _nameController = TextEditingController(text: item?.name ?? '');
    _addressController = TextEditingController(text: item?.address ?? '');
    _selectedType = _types.contains(item?.type) ? item!.type : 'testing';
    _assignedFighterIds = {...(item?.assignedFighterIds ?? const <String>[])};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final mutation = ref.watch(locationMutationControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth =
        width < 760 ? width * 0.9 : AppLayout.kpiCardWidth(context) * 2.8;

    return AlertDialog(
      title: Text(loc.tr(isEdit ? 'locations.edit' : 'locations.add')),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: loc.tr('locations.name'),
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                _buildTextField(
                  controller: _addressController,
                  label: loc.tr('locations.address'),
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: loc.tr('locations.type'),
                    border: const OutlineInputBorder(),
                  ),
                  items: _types
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(loc.tr(_locationTypeLabelKey(type))),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
                ),
                SizedBox(height: AppLayout.mediumGap(context)),
                Text(
                  loc.tr('locations.assignedFighters'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                if (widget.fighters.isEmpty)
                  Text(
                    loc.tr('locations.noFighters'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: AppLayout.smallGap(context),
                    runSpacing: AppLayout.smallGap(context),
                    children: widget.fighters.map((fighter) {
                      final isSelected =
                          _assignedFighterIds.contains(fighter.uid);
                      return FilterChip(
                        label: Text(fighter.fullName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _assignedFighterIds.add(fighter.uid);
                            } else {
                              _assignedFighterIds.remove(fighter.uid);
                            }
                          });
                        },
                      );
                    }).toList(),
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
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  final notifier = ref.read(
                    locationMutationControllerProvider.notifier,
                  );
                  final assignedIds = _assignedFighterIds.toList()..sort();
                  if (isEdit) {
                    await notifier.update(
                      id: widget.location!.id,
                      name: _nameController.text,
                      address: _addressController.text,
                      type: _selectedType,
                      assignedFighterIds: assignedIds,
                    );
                  } else {
                    await notifier.create(
                      name: _nameController.text,
                      address: _addressController.text,
                      type: _selectedType,
                      assignedFighterIds: assignedIds,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.l10n.tr('fighters.required');
        }
        return null;
      },
    );
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

String _locationTypeLabelKey(String type) {
  switch (type) {
    case 'training':
      return 'locations.typeTraining';
    case 'event':
      return 'locations.typeEvent';
    default:
      return 'locations.typeTesting';
  }
}
