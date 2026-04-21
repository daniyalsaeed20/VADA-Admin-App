import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../domain/fighter.dart';
import 'fighters_controller.dart';

class FightersPage extends ConsumerStatefulWidget {
  const FightersPage({super.key});

  @override
  ConsumerState<FightersPage> createState() => _FightersPageState();
}

class _FightersPageState extends ConsumerState<FightersPage> {
  static const List<int> _rowsPerPageOptions = [10, 20, 50];
  final TextEditingController _searchController = TextEditingController();
  int _rowsPerPage = _rowsPerPageOptions.first;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final fightersAsync = ref.watch(fightersStreamProvider);
    final mutationState = ref.watch(fighterMutationControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 760;

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
                  loc.tr('fighters.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                FilledButton.icon(
                  onPressed: () {
                    _openFighterDialog(context: context, ref: ref);
                  },
                  icon: const Icon(Icons.add),
                  label: Text(loc.tr('fighters.create')),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  loc.tr('fighters.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    _openFighterDialog(context: context, ref: ref);
                  },
                  icon: const Icon(Icons.add),
                  label: Text(loc.tr('fighters.create')),
                ),
              ],
            ),
          if (mutationState.errorMessage != null)
            _MutationBanner(
              message: loc.tr(mutationState.errorMessage!),
              isError: true,
            ),
          if (mutationState.successMessage != null)
            _MutationBanner(
              message: loc.tr(mutationState.successMessage!),
              isError: false,
            ),
          SizedBox(height: AppLayout.mediumGap(context)),
          Expanded(
            child: fightersAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: AppLayout.smallGap(context)),
                    Text(loc.tr('fighters.loading')),
                  ],
                ),
              ),
              error: (error, stackTrace) => Center(
                child: _FightersSurface(
                  child: Padding(
                    padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(height: AppLayout.smallGap(context)),
                        Text(loc.tr('fighters.error')),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => ref.refresh(fightersStreamProvider),
                          icon: const Icon(Icons.refresh),
                          label: Text(loc.tr('common.retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (fighters) {
                if (fighters.isEmpty) {
                  return _EmptyFightersState(
                    onCreatePressed: () =>
                        _openFighterDialog(context: context, ref: ref),
                  );
                }
                final filtered = _filterFighters(fighters);
                final totalPages =
                    math.max(1, (filtered.length / _rowsPerPage).ceil());
                final currentPage = _page.clamp(0, totalPages - 1).toInt();
                final startIndex =
                    filtered.isEmpty ? 0 : currentPage * _rowsPerPage;
                final endIndex = filtered.isEmpty
                    ? 0
                    : math.min(startIndex + _rowsPerPage, filtered.length);
                final pageItems = filtered.isEmpty
                    ? const <Fighter>[]
                    : filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    _FightersFilters(
                      searchController: _searchController,
                    ),
                    SizedBox(height: AppLayout.mediumGap(context)),
                    Expanded(
                      child: pageItems.isEmpty
                          ? _NoResultsState(
                              onClearFilters: _clearFilters,
                            )
                          : width < 900
                              ? _FightersMobileList(
                                  fighters: pageItems,
                                  onEdit: (fighter) => _openFighterDialog(
                                    context: context,
                                    ref: ref,
                                    fighter: fighter,
                                  ),
                                )
                              : _FightersTable(
                                  fighters: pageItems,
                                  onEdit: (fighter) => _openFighterDialog(
                                    context: context,
                                    ref: ref,
                                    fighter: fighter,
                                  ),
                                ),
                    ),
                    if (filtered.isNotEmpty) ...[
                      SizedBox(height: AppLayout.smallGap(context)),
                      _FightersPagination(
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
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFighterDialog({
    required BuildContext context,
    required WidgetRef ref,
    Fighter? fighter,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FighterDialog(fighter: fighter),
    );
    ref.read(fighterMutationControllerProvider.notifier).clearMessages();
  }

  List<Fighter> _filterFighters(List<Fighter> fighters) {
    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isEmpty) {
      return fighters;
    }

    return fighters.where((fighter) {
      return fighter.fullName.toLowerCase().contains(searchQuery) ||
          fighter.email.toLowerCase().contains(searchQuery) ||
          fighter.phone.toLowerCase().contains(searchQuery);
    }).toList();
  }

  void _onFilterChanged() {
    setState(() {
      _page = 0;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _page = 0;
    });
  }
}

class _FightersFilters extends StatelessWidget {
  const _FightersFilters({
    required this.searchController,
  });

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppLayout.smallGap(context)),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          labelText: loc.tr('fighters.searchPlaceholder'),
          prefixIcon: const Icon(Icons.search),
          isDense: true,
        ),
      ),
    );
  }
}

class _FightersPagination extends StatelessWidget {
  const _FightersPagination({
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

class _EmptyFightersState extends StatelessWidget {
  const _EmptyFightersState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    return Center(
      child: _FightersSurface(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.cardPadding(context) * 1.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_mma_outlined, size: 32),
              SizedBox(height: AppLayout.smallGap(context)),
              Text(loc.tr('fighters.empty')),
              SizedBox(height: AppLayout.mediumGap(context)),
              FilledButton.icon(
                onPressed: onCreatePressed,
                icon: const Icon(Icons.add),
                label: Text(loc.tr('fighters.create')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    return Center(
      child: _FightersSurface(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.cardPadding(context) * 1.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_outlined, size: 32),
              SizedBox(height: AppLayout.smallGap(context)),
              Text(loc.tr('fighters.noResults')),
              SizedBox(height: AppLayout.mediumGap(context)),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear),
                label: Text(loc.tr('fighters.clearFilters')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FightersSurface extends StatelessWidget {
  const _FightersSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _FightersMobileList extends ConsumerWidget {
  const _FightersMobileList({
    required this.fighters,
    required this.onEdit,
  });

  final List<Fighter> fighters;
  final Future<void> Function(Fighter fighter) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      itemCount: fighters.length,
      separatorBuilder: (_, __) =>
          SizedBox(height: AppLayout.smallGap(context)),
      itemBuilder: (context, index) {
        final fighter = fighters[index];
        return _FightersSurface(
          child: Padding(
            padding: EdgeInsets.all(AppLayout.cardPadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _avatarColorFor(fighter.fullName),
                      child: Text(
                        _initials(fighter.fullName),
                        style: TextStyle(
                          color: _avatarTextColorFor(fighter.fullName),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: AppLayout.smallGap(context)),
                    Expanded(
                      child: Text(
                        fighter.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _FighterStatusChip(disabled: fighter.disabled),
                  ],
                ),
                SizedBox(height: AppLayout.mediumGap(context)),
                _FighterInfoLine(
                  icon: Icons.mail_outline,
                  value: fighter.email,
                ),
                _FighterInfoLine(
                  icon: Icons.phone_outlined,
                  value: fighter.phone,
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.tr('fighters.account'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Switch(
                      value: !fighter.disabled,
                      onChanged: (enabled) async {
                        await ref
                            .read(fighterMutationControllerProvider.notifier)
                            .toggleAccess(uid: fighter.uid, disabled: !enabled);
                      },
                    ),
                    IconButton(
                      tooltip: context.l10n.tr('fighters.edit'),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(fighter),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FighterInfoLine extends StatelessWidget {
  const _FighterInfoLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppLayout.smallGap(context) * 0.6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.steel),
          SizedBox(width: AppLayout.smallGap(context)),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FighterStatusChip extends StatelessWidget {
  const _FighterStatusChip({required this.disabled});

  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final fg = disabled ? AppColors.redDark : AppColors.success;
    final bg = fg.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        disabled ? loc.tr('fighters.disabled') : loc.tr('fighters.enabled'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

Color _avatarColorFor(String value) {
  const palette = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
    Color(0xFF84CC16),
  ];
  final index = value.trim().toLowerCase().hashCode.abs() % palette.length;
  return palette[index];
}

Color _avatarTextColorFor(String value) {
  final background = _avatarColorFor(value);
  return background.computeLuminance() > 0.6 ? Colors.black : Colors.white;
}

class _FightersTable extends ConsumerStatefulWidget {
  const _FightersTable({
    required this.fighters,
    required this.onEdit,
  });

  final List<Fighter> fighters;
  final Future<void> Function(Fighter fighter) onEdit;

  @override
  ConsumerState<_FightersTable> createState() => _FightersTableState();
}

class _FightersTableState extends ConsumerState<_FightersTable> {
  late final ScrollController _horizontalController;
  late final ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final isCompact = MediaQuery.sizeOf(context).width < 1100;

    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalController,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  dataRowMinHeight: 62,
                  dataRowMaxHeight: 72,
                  columnSpacing: isCompact
                      ? AppLayout.mediumGap(context)
                      : AppLayout.largeGap(context) * 1.8,
                  columns: [
                    DataColumn(label: Text(loc.tr('fighters.fullName'))),
                    DataColumn(label: Text(loc.tr('fighters.email'))),
                    DataColumn(label: Text(loc.tr('fighters.phone'))),
                    DataColumn(label: Text(loc.tr('fighters.status'))),
                    DataColumn(label: Text(loc.tr('fighters.actions'))),
                  ],
                  rows: widget.fighters.map((fighter) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    _avatarColorFor(fighter.fullName),
                                child: Text(
                                  _initials(fighter.fullName),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: _avatarTextColorFor(
                                          fighter.fullName,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              SizedBox(width: AppLayout.smallGap(context)),
                              Text(fighter.fullName),
                            ],
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              fighter.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(fighter.phone)),
                        DataCell(
                            _FighterStatusChip(disabled: fighter.disabled)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: loc.tr('fighters.edit'),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => widget.onEdit(fighter),
                              ),
                              Switch(
                                value: !fighter.disabled,
                                onChanged: (isEnabled) async {
                                  await ref
                                      .read(
                                        fighterMutationControllerProvider
                                            .notifier,
                                      )
                                      .toggleAccess(
                                        uid: fighter.uid,
                                        disabled: !isEnabled,
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FighterDialog extends ConsumerStatefulWidget {
  const _FighterDialog({this.fighter});

  final Fighter? fighter;

  @override
  ConsumerState<_FighterDialog> createState() => _FighterDialogState();
}

class _FighterDialogState extends ConsumerState<_FighterDialog> {
  static final DateFormat _dobFormat = DateFormat('yyyy-MM-dd');
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _genderController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _primaryContactController;
  late final TextEditingController _passwordController;
  DateTime? _selectedDateOfBirth;
  String? _selectedGender;
  bool _disabled = false;

  bool get isEdit => widget.fighter != null;

  @override
  void initState() {
    super.initState();
    final fighter = widget.fighter;
    _fullNameController = TextEditingController(text: fighter?.fullName ?? '');
    _dateOfBirthController = TextEditingController(
      text: fighter?.dateOfBirth ?? '',
    );
    _selectedDateOfBirth = _parseDateOfBirth(fighter?.dateOfBirth);
    _genderController = TextEditingController(text: fighter?.gender ?? '');
    _selectedGender = _normalizeGender(fighter?.gender);
    _phoneController = TextEditingController(text: fighter?.phone ?? '');
    _emailController = TextEditingController(text: fighter?.email ?? '');
    _addressController = TextEditingController(text: fighter?.address ?? '');
    _primaryContactController = TextEditingController(
      text: fighter?.primaryContactPerson ?? '',
    );
    _passwordController = TextEditingController();
    _disabled = fighter?.disabled ?? false;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    _genderController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _primaryContactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final mutation = ref.watch(fighterMutationControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth =
        width < 720 ? width * 0.9 : AppLayout.kpiCardWidth(context) * 2.5;
    final showTwoColumns = width > 950;

    return AlertDialog(
      title: Text(
        isEdit ? loc.tr('fighters.edit') : loc.tr('fighters.create'),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: AppLayout.smallGap(context),
              runSpacing: AppLayout.smallGap(context),
              children: [
                _buildTextField(
                  controller: _fullNameController,
                  label: loc.tr('fighters.fullName'),
                  requiredField: true,
                  width: showTwoColumns ? dialogWidth * 0.48 : dialogWidth,
                ),
                _buildTextField(
                  controller: _dateOfBirthController,
                  label: loc.tr('fighters.dateOfBirth'),
                  requiredField: true,
                  readOnly: true,
                  suffixIcon: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickDateOfBirth,
                  validator: _validateDateOfBirth,
                  width: showTwoColumns ? dialogWidth * 0.48 : dialogWidth,
                ),
                _buildTextField(
                  controller: _phoneController,
                  label: loc.tr('fighters.phone'),
                  requiredField: true,
                  width: showTwoColumns ? dialogWidth * 0.48 : dialogWidth,
                ),
                SizedBox(
                  width: showTwoColumns ? dialogWidth * 0.48 : dialogWidth,
                  child: _buildGenderField(),
                ),
                _buildTextField(
                  controller: _emailController,
                  label: loc.tr('fighters.email'),
                  requiredField: true,
                  width: showTwoColumns ? dialogWidth * 0.48 : dialogWidth,
                ),
                _buildTextField(
                  controller: _addressController,
                  label: loc.tr('fighters.address'),
                  requiredField: true,
                  width: showTwoColumns ? dialogWidth * 0.48 : dialogWidth,
                ),
                _buildTextField(
                  controller: _primaryContactController,
                  label: loc.tr('fighters.primaryContact'),
                  requiredField: true,
                  width: dialogWidth,
                ),
                if (!isEdit)
                  _buildTextField(
                    controller: _passwordController,
                    label: loc.tr('fighters.password'),
                    requiredField: true,
                    obscureText: true,
                    width: dialogWidth,
                  ),
                SizedBox(
                  width: dialogWidth,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: !_disabled,
                    title: Text(loc.tr('fighters.account')),
                    subtitle: Text(
                      _disabled
                          ? loc.tr('fighters.disabled')
                          : loc.tr('fighters.enabled'),
                    ),
                    onChanged: (enabled) {
                      setState(() {
                        _disabled = !enabled;
                      });
                    },
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
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  final notifier = ref.read(
                    fighterMutationControllerProvider.notifier,
                  );
                  if (isEdit) {
                    await notifier.update(
                      uid: widget.fighter!.uid,
                      fullName: _fullNameController.text,
                      dateOfBirth: _dateOfBirthController.text,
                      gender: _selectedGender!,
                      phone: _phoneController.text,
                      email: _emailController.text,
                      address: _addressController.text,
                      primaryContactPerson: _primaryContactController.text,
                      disabled: _disabled,
                    );
                  } else {
                    await notifier.create(
                      fullName: _fullNameController.text,
                      dateOfBirth: _dateOfBirthController.text,
                      gender: _selectedGender!,
                      phone: _phoneController.text,
                      email: _emailController.text,
                      address: _addressController.text,
                      primaryContactPerson: _primaryContactController.text,
                      password: _passwordController.text,
                      disabled: _disabled,
                    );
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: Text(
            mutation.isLoading
                ? context.l10n.tr('common.loading')
                : loc.tr('fighters.save'),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool requiredField,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: suffixIcon,
        ),
        validator: validator ??
            (value) {
              if (requiredField && (value == null || value.trim().isEmpty)) {
                return context.l10n.tr('fighters.required');
              }
              return null;
            },
      ),
    );
  }

  DateTime? _parseDateOfBirth(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    try {
      return _dobFormat.parseStrict(rawValue.trim());
    } catch (_) {
      return null;
    }
  }

  String? _validateDateOfBirth(String? value) {
    final loc = context.l10n;
    if (value == null || value.trim().isEmpty) {
      return loc.tr('fighters.required');
    }
    DateTime parsed;
    try {
      parsed = _dobFormat.parseStrict(value.trim());
    } catch (_) {
      return loc.tr('fighters.invalidDate');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final age = today.year -
        parsed.year -
        ((today.month < parsed.month ||
                (today.month == parsed.month && today.day < parsed.day))
            ? 1
            : 0);
    if (parsed.isAfter(today)) {
      return loc.tr('fighters.futureDob');
    }
    if (age < 12) {
      return loc.tr('fighters.minAge');
    }
    if (age > 100) {
      return loc.tr('fighters.unrealisticDob');
    }
    return null;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _selectedDateOfBirth ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 100, 1, 1),
      lastDate: DateTime(now.year - 12, 12, 31),
      helpText: context.l10n.tr('fighters.selectDate'),
    );
    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dateOfBirthController.text = _dobFormat.format(picked);
      });
    }
  }

  Widget _buildGenderField() {
    final loc = context.l10n;
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      decoration: InputDecoration(
        labelText: loc.tr('fighters.gender'),
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(
          value: 'male',
          child: Text(loc.tr('fighters.genderMale')),
        ),
        DropdownMenuItem(
          value: 'female',
          child: Text(loc.tr('fighters.genderFemale')),
        ),
        DropdownMenuItem(
          value: 'other',
          child: Text(loc.tr('fighters.genderOther')),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
          _genderController.text = value ?? '';
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return loc.tr('fighters.required');
        }
        return null;
      },
    );
  }

  String? _normalizeGender(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    final value = rawValue.trim().toLowerCase();
    if (value == 'male' || value == 'female' || value == 'other') {
      return value;
    }
    if (value == 'm') {
      return 'male';
    }
    if (value == 'f') {
      return 'female';
    }
    return 'other';
  }
}
