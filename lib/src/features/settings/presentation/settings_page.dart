import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_layout.dart';
import '../domain/notification_settings.dart';
import 'notification_settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _defaultScheduleUpdateTitleTemplate =
      'Schedule updated • {fighterName}';
  static const _defaultScheduleUpdateBodyTemplate = '{date} • {startTime}-{endTime}\n'
      'Location: {locationName}\n'
      'Contact: {contactName}\n'
      'Repeat: (auto)\n'
      '{notes}';

  final _schedTitleCtrl = TextEditingController();
  final _schedBodyCtrl = TextEditingController();

  final _schedTitleFocus = FocusNode();
  final _schedBodyFocus = FocusNode();

  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isPasswordSaving = false;
  String? _passwordError;
  String? _passwordSuccess;

  bool _initialized = false;
  bool _enableAdminMessages = true;
  bool _enableScheduleUpdates = true;
  _ActiveScheduleField _activeField = _ActiveScheduleField.none;

  @override
  void dispose() {
    _schedTitleCtrl.dispose();
    _schedBodyCtrl.dispose();
    _schedTitleFocus.dispose();
    _schedBodyFocus.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _setActiveField(_ActiveScheduleField field) {
    if (_activeField == field) return;
    setState(() => _activeField = field);
  }

  TextEditingController? _activeController() {
    switch (_activeField) {
      case _ActiveScheduleField.scheduleTitle:
        return _schedTitleCtrl;
      case _ActiveScheduleField.scheduleBody:
        return _schedBodyCtrl;
      case _ActiveScheduleField.none:
        return null;
    }
  }

  void _insertPlaceholder(String token) {
    final ctrl = _activeController();
    if (ctrl == null) return;

    final text = ctrl.text;
    final sel = ctrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final safeStart = (start < 0 || start > text.length) ? text.length : start;
    final safeEnd = (end < 0 || end > text.length) ? text.length : end;

    final next = text.replaceRange(safeStart, safeEnd, token);
    ctrl.value = ctrl.value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: safeStart + token.length),
      composing: TextRange.empty,
    );
    setState(() {});
  }

  void _useDefaultScheduleTitleTemplate() {
    _schedTitleCtrl.text = _defaultScheduleUpdateTitleTemplate;
    _schedTitleCtrl.selection = TextSelection.collapsed(
      offset: _schedTitleCtrl.text.length,
    );
    _setActiveField(_ActiveScheduleField.scheduleTitle);
    _schedTitleFocus.requestFocus();
    setState(() {});
  }

  void _useDefaultScheduleBodyTemplate() {
    _schedBodyCtrl.text = _defaultScheduleUpdateBodyTemplate;
    _schedBodyCtrl.selection = TextSelection.collapsed(
      offset: _schedBodyCtrl.text.length,
    );
    _setActiveField(_ActiveScheduleField.scheduleBody);
    _schedBodyFocus.requestFocus();
    setState(() {});
  }

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    setState(() {
      _passwordError = null;
      _passwordSuccess = null;
    });

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      setState(() => _passwordError = 'Not signed in.');
      return;
    }
    final email = user.email;
    if (email == null || email.trim().isEmpty) {
      setState(() => _passwordError = 'This account has no email address.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _passwordError = 'New password and confirmation do not match.');
      return;
    }
    if (newPassword.trim().length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters.');
      return;
    }

    setState(() => _isPasswordSaving = true);
    try {
      final credential =
          EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      setState(() {
        _passwordSuccess = 'Password updated';
        _currentPasswordCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _passwordError = e.message ?? e.code);
    } catch (e) {
      setState(() => _passwordError = e.toString());
    } finally {
      if (mounted) setState(() => _isPasswordSaving = false);
    }
  }

  Future<void> _copyPlaceholder(BuildContext context, String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $token')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final auth = ref.watch(firebaseAuthProvider);
    final user = auth.currentUser;
    final settingsAsync = ref.watch(notificationSettingsStreamProvider);
    final mutation = ref.watch(notificationSettingsMutationControllerProvider);

    final settings = settingsAsync.asData?.value;
    if (!_initialized && settings != null) {
      _initialized = true;
      _enableAdminMessages = settings.enableAdminMessages;
      _enableScheduleUpdates = settings.enableScheduleUpdates;
      _schedTitleCtrl.text = settings.scheduleUpdateTitleTemplate;
      _schedBodyCtrl.text = settings.scheduleUpdateBodyTemplate;
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppLayout.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.tr('nav.settings'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              Text(
                'Admin & Notifications',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(height: AppLayout.sectionGap(context)),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.tr('settings.adminProfile'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: Text(user?.email ?? '—'),
                        subtitle: Text('UID: ${user?.uid ?? '—'}'),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Security',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      TextField(
                        controller: _currentPasswordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Current password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      TextField(
                        controller: _newPasswordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      TextField(
                        controller: _confirmPasswordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _isPasswordSaving
                                ? null
                                : () => _changePassword(
                                      currentPassword:
                                          _currentPasswordCtrl.text.trim(),
                                      newPassword: _newPasswordCtrl.text,
                                      confirmPassword:
                                          _confirmPasswordCtrl.text,
                                    ),
                            icon: _isPasswordSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.lock_reset_outlined),
                            label: Text(
                              _isPasswordSaving ? 'Updating...' : 'Update password',
                            ),
                          ),
                          if (_passwordSuccess != null) ...[
                            SizedBox(width: AppLayout.smallGap(context)),
                            Text(_passwordSuccess!),
                          ],
                        ],
                      ),
                      if (_passwordError != null) ...[
                        SizedBox(height: AppLayout.smallGap(context)),
                        Text(
                          _passwordError!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppLayout.mediumGap(context)),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.cardPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Notifications',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (mutation.isSaving)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable admin messages'),
                        subtitle:
                            const Text('Allows queuing admin_message notifications.'),
                        value: _enableAdminMessages,
                        onChanged: (v) => setState(() => _enableAdminMessages = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable schedule updates'),
                        subtitle: const Text(
                          'Allows queuing schedule_update notifications when schedules are created/edited.',
                        ),
                        value: _enableScheduleUpdates,
                        onChanged: (v) =>
                            setState(() => _enableScheduleUpdates = v),
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      Text(
                        'Schedule update templates (optional)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      _PlaceholderBar(
                        activeField: _activeField,
                        onInsert: _insertPlaceholder,
                        onCopy: (token) => _copyPlaceholder(context, token),
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      TextField(
                        controller: _schedTitleCtrl,
                        focusNode: _schedTitleFocus,
                        onTap: () =>
                            _setActiveField(_ActiveScheduleField.scheduleTitle),
                        decoration: InputDecoration(
                          labelText: 'Schedule update title template',
                          helperText:
                              'Placeholders: {fighterName} {date} {startTime} {endTime} {locationName} {contactName}',
                          border: const OutlineInputBorder(),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton(
                              onPressed: _useDefaultScheduleTitleTemplate,
                              child: const Text('Use default'),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minHeight: 40,
                            minWidth: 110,
                          ),
                        ),
                      ),
                      SizedBox(height: AppLayout.smallGap(context)),
                      TextField(
                        controller: _schedBodyCtrl,
                        focusNode: _schedBodyFocus,
                        onTap: () =>
                            _setActiveField(_ActiveScheduleField.scheduleBody),
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: 'Schedule update body template',
                          helperText:
                              'Placeholders: {fighterName} {date} {startTime} {endTime} {locationName} {contactName} {notes}',
                          border: const OutlineInputBorder(),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton(
                              onPressed: _useDefaultScheduleBodyTemplate,
                              child: const Text('Use default'),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minHeight: 40,
                            minWidth: 110,
                          ),
                        ),
                      ),
                      SizedBox(height: AppLayout.mediumGap(context)),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: mutation.isSaving
                                ? null
                                : () async {
                                    final next =
                                        NotificationSettings.defaults().copyWith(
                                      enableAdminMessages: _enableAdminMessages,
                                      enableScheduleUpdates: _enableScheduleUpdates,
                                      scheduleUpdateTitleTemplate:
                                          _schedTitleCtrl.text,
                                      scheduleUpdateBodyTemplate: _schedBodyCtrl.text,
                                    );
                                    await ref
                                        .read(
                                          notificationSettingsMutationControllerProvider
                                              .notifier,
                                        )
                                        .save(next);
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(mutation.isSaving ? 'Saving...' : 'Save'),
                          ),
                          SizedBox(width: AppLayout.smallGap(context)),
                          if (mutation.successMessage != null)
                            Text(
                              mutation.successMessage!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          if (mutation.errorMessage != null)
                            Expanded(
                              child: Text(
                                mutation.errorMessage!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      if (settingsAsync.isLoading)
                        Padding(
                          padding:
                              EdgeInsets.only(top: AppLayout.smallGap(context)),
                          child: Text(
                            loc.tr('common.loading'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ActiveScheduleField {
  none,
  scheduleTitle,
  scheduleBody,
}

class _PlaceholderBar extends StatelessWidget {
  const _PlaceholderBar({
    required this.activeField,
    required this.onInsert,
    required this.onCopy,
  });

  final _ActiveScheduleField activeField;
  final ValueChanged<String> onInsert;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = const [
      '{fighterName}',
      '{date}',
      '{startTime}',
      '{endTime}',
      '{locationName}',
      '{contactName}',
      '{notes}',
    ];

    final activeLabel = switch (activeField) {
      _ActiveScheduleField.none =>
        'Select a template field, then click a placeholder.',
      _ActiveScheduleField.scheduleTitle =>
        'Inserting into: Schedule update title',
      _ActiveScheduleField.scheduleBody =>
        'Inserting into: Schedule update body',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activeLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tokens.map((t) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActionChip(
                    label: Text(t),
                    onPressed: activeField == _ActiveScheduleField.none
                        ? null
                        : () => onInsert(t),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () => onCopy(t),
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

