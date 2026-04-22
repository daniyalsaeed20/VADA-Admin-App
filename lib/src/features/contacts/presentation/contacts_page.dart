import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../domain/contact.dart';
import 'contacts_controller.dart';

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
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
    final contactsAsync = ref.watch(contactsStreamProvider);
    final mutation = ref.watch(contactMutationControllerProvider);
    final errorMessage = mutation.errorMessage;
    final successMessage = mutation.successMessage;
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 900;

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
                  loc.tr('contacts.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                FilledButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.add),
                  label: Text(loc.tr('contacts.add')),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  loc.tr('contacts.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.add),
                  label: Text(loc.tr('contacts.add')),
                ),
              ],
            ),
          if (errorMessage != null)
            _MutationBanner(message: loc.tr(errorMessage), isError: true),
          if (successMessage != null)
            _MutationBanner(
              message: loc.tr(successMessage),
              isError: false,
            ),
          SizedBox(height: AppLayout.mediumGap(context)),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: loc.tr('contacts.search'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (_) => setState(() => _page = 0),
          ),
          SizedBox(height: AppLayout.mediumGap(context)),
          Expanded(
            child: contactsAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: AppLayout.smallGap(context)),
                    Text(loc.tr('contacts.loading')),
                  ],
                ),
              ),
              error: (_, _) => Center(
                child: Text(loc.tr('contacts.error')),
              ),
              data: (contacts) {
                final filtered = _filterContacts(contacts);
                if (contacts.isEmpty) {
                  return Center(
                    child: Text(loc.tr('contacts.empty')),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(loc.tr('contacts.noResults')),
                  );
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
                    ? const <Contact>[]
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
                                final contact = pageItems[index];
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
                                                contact.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: loc.tr('contacts.edit'),
                                              onPressed: () =>
                                                  _openEditDialog(contact),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: AppLayout.smallGap(context),
                                        ),
                                        Text(contact.phone),
                                        Text(contact.email),
                                        Text(contact.address),
                                        SizedBox(
                                          height: AppLayout.smallGap(context),
                                        ),
                                        Chip(
                                          label: Text(
                                            loc.tr(_roleLabelKey(contact.role)),
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
                                    label: Text(loc.tr('contacts.name')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('contacts.phone')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('contacts.email')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('contacts.address')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('contacts.role')),
                                  ),
                                  DataColumn(
                                    label: Text(loc.tr('contacts.actions')),
                                  ),
                                ],
                                rows: pageItems.map((contact) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(contact.name)),
                                      DataCell(Text(contact.phone)),
                                      DataCell(Text(contact.email)),
                                      DataCell(
                                        SizedBox(
                                          width: 220,
                                          child: Text(
                                            contact.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(loc
                                            .tr(_roleLabelKey(contact.role))),
                                      ),
                                      DataCell(
                                        IconButton(
                                          tooltip: loc.tr('contacts.edit'),
                                          onPressed: () =>
                                              _openEditDialog(contact),
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
                    _ContactsPagination(
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

  List<Contact> _filterContacts(List<Contact> contacts) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return contacts;
    }
    return contacts.where((contact) {
      return contact.name.toLowerCase().contains(query) ||
          contact.email.toLowerCase().contains(query) ||
          contact.phone.toLowerCase().contains(query) ||
          contact.address.toLowerCase().contains(query) ||
          contact.role.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openCreateDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _ContactDialog(),
    );
    if (mounted) {
      ref.read(contactMutationControllerProvider.notifier).clearMessages();
    }
  }

  Future<void> _openEditDialog(Contact contact) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ContactDialog(contact: contact),
    );
    if (mounted) {
      ref.read(contactMutationControllerProvider.notifier).clearMessages();
    }
  }
}

class _ContactsPagination extends StatelessWidget {
  const _ContactsPagination({
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

class _ContactDialog extends ConsumerStatefulWidget {
  const _ContactDialog({this.contact});

  final Contact? contact;

  @override
  ConsumerState<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends ConsumerState<_ContactDialog> {
  static const List<String> _roles = [
    'trainer',
    'manager',
    'promoter',
    'other'
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  String _selectedRole = 'other';

  bool get isEdit => widget.contact != null;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _nameController = TextEditingController(text: contact?.name ?? '');
    _phoneController = TextEditingController(text: contact?.phone ?? '');
    _emailController = TextEditingController(text: contact?.email ?? '');
    _addressController = TextEditingController(text: contact?.address ?? '');
    _selectedRole = normalizeContactRole(contact?.role);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final mutation = ref.watch(contactMutationControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth =
        width < 720 ? width * 0.9 : AppLayout.kpiCardWidth(context) * 2.4;

    return AlertDialog(
      title: Text(loc.tr(isEdit ? 'contacts.edit' : 'contacts.add')),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: loc.tr('contacts.name'),
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                _buildTextField(
                  controller: _phoneController,
                  label: loc.tr('contacts.phone'),
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                _buildTextField(
                  controller: _emailController,
                  label: loc.tr('contacts.email'),
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                _buildTextField(
                  controller: _addressController,
                  label: loc.tr('contacts.address'),
                ),
                SizedBox(height: AppLayout.smallGap(context)),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: InputDecoration(
                    labelText: loc.tr('contacts.role'),
                    border: const OutlineInputBorder(),
                  ),
                  items: _roles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(loc.tr(_roleLabelKey(role))),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
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
                  final notifier = ref.read(
                    contactMutationControllerProvider.notifier,
                  );
                  if (isEdit) {
                    final contact = widget.contact;
                    if (contact == null) {
                      return;
                    }
                    await notifier.update(
                      id: contact.id,
                      name: _nameController.text,
                      phone: _phoneController.text,
                      email: _emailController.text,
                      address: _addressController.text,
                      role: _selectedRole,
                    );
                  } else {
                    await notifier.create(
                      name: _nameController.text,
                      phone: _phoneController.text,
                      email: _emailController.text,
                      address: _addressController.text,
                      role: _selectedRole,
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

String _roleLabelKey(String role) {
  switch (normalizeContactRole(role)) {
    case 'trainer':
      return 'contacts.roleTrainer';
    case 'manager':
      return 'contacts.roleManager';
    case 'promoter':
      return 'contacts.rolePromoter';
    default:
      return 'contacts.roleOther';
  }
}
