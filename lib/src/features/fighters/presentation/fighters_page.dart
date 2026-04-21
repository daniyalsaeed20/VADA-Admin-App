import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/localization_x.dart';
import '../domain/fighter.dart';
import 'fighters_controller.dart';

class FightersPage extends ConsumerWidget {
  const FightersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.l10n;
    final fightersAsync = ref.watch(fightersStreamProvider);
    final mutationState = ref.watch(fighterMutationControllerProvider);
    final isNarrow = MediaQuery.sizeOf(context).width < 760;

    return Padding(
      padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 10),
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
          if (mutationState.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              loc.tr(mutationState.errorMessage!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (mutationState.successMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              loc.tr(mutationState.successMessage!),
              style: const TextStyle(color: Colors.green),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: fightersAsync.when(
              loading: () => Center(child: Text(loc.tr('fighters.loading'))),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.tr('fighters.error')),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.refresh(fightersStreamProvider),
                      child: Text(loc.tr('common.retry')),
                    ),
                  ],
                ),
              ),
              data: (fighters) {
                if (fighters.isEmpty) {
                  return Center(child: Text(loc.tr('fighters.empty')));
                }
                return _FightersTable(fighters: fighters);
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
}

class _FightersTable extends ConsumerWidget {
  const _FightersTable({required this.fighters});

  final List<Fighter> fighters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.l10n;
    final isCompact = MediaQuery.sizeOf(context).width < 1100;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: isCompact ? 16 : 36,
            columns: [
              DataColumn(label: Text(loc.tr('fighters.fullName'))),
              DataColumn(label: Text(loc.tr('fighters.email'))),
              DataColumn(label: Text(loc.tr('fighters.phone'))),
              DataColumn(label: Text(loc.tr('fighters.status'))),
              DataColumn(label: Text(loc.tr('fighters.actions'))),
            ],
            rows: fighters.map((fighter) {
              return DataRow(
                cells: [
                  DataCell(Text(fighter.fullName)),
                  DataCell(Text(fighter.email)),
                  DataCell(Text(fighter.phone)),
                  DataCell(
                    Chip(
                      label: Text(
                        fighter.disabled
                            ? loc.tr('fighters.disabled')
                            : loc.tr('fighters.enabled'),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await showDialog<void>(
                              context: context,
                              builder: (_) => _FighterDialog(fighter: fighter),
                            );
                          },
                        ),
                        Switch(
                          value: !fighter.disabled,
                          onChanged: (isEnabled) async {
                            await ref
                                .read(
                                    fighterMutationControllerProvider.notifier)
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
    final dialogWidth = MediaQuery.sizeOf(context).width < 640
        ? MediaQuery.sizeOf(context).width * 0.88
        : 500.0;

    return AlertDialog(
      title: Text(
        isEdit ? loc.tr('fighters.edit') : loc.tr('fighters.create'),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: _fullNameController,
                  label: loc.tr('fighters.fullName'),
                  requiredField: true,
                ),
                _buildTextField(
                  controller: _dateOfBirthController,
                  label: loc.tr('fighters.dateOfBirth'),
                  requiredField: true,
                  readOnly: true,
                  suffixIcon: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickDateOfBirth,
                  validator: _validateDateOfBirth,
                ),
                _buildTextField(
                  controller: _phoneController,
                  label: loc.tr('fighters.phone'),
                  requiredField: true,
                ),
                _buildGenderField(),
                _buildTextField(
                  controller: _emailController,
                  label: loc.tr('fighters.email'),
                  requiredField: true,
                ),
                _buildTextField(
                  controller: _addressController,
                  label: loc.tr('fighters.address'),
                  requiredField: true,
                ),
                _buildTextField(
                  controller: _primaryContactController,
                  label: loc.tr('fighters.primaryContact'),
                  requiredField: true,
                ),
                if (!isEdit)
                  _buildTextField(
                    controller: _passwordController,
                    label: loc.tr('fighters.password'),
                    requiredField: true,
                    obscureText: true,
                  ),
                SwitchListTile(
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
    final today = DateTime.now();
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
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
      ),
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
