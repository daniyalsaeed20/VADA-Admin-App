import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_layout.dart';
import '../../notifications/domain/notification_message_composer.dart';
import '../domain/notification_settings.dart';
import 'notification_settings_controller.dart';
import 'widgets/notification_template_editor.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _schedTitleCtrl = TextEditingController();
  final _schedBodyCtrl = TextEditingController();
  final _changeApprovedTitleCtrl = TextEditingController();
  final _changeApprovedBodyCtrl = TextEditingController();
  final _changeRejectedTitleCtrl = TextEditingController();
  final _changeRejectedBodyCtrl = TextEditingController();

  final _schedTitleFocus = FocusNode();
  final _schedBodyFocus = FocusNode();
  final _changeApprovedTitleFocus = FocusNode();
  final _changeApprovedBodyFocus = FocusNode();
  final _changeRejectedTitleFocus = FocusNode();
  final _changeRejectedBodyFocus = FocusNode();

  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isPasswordSaving = false;
  String? _passwordError;
  String? _passwordSuccess;

  bool _initialized = false;
  bool _enableAdminMessages = true;
  bool _enableScheduleUpdates = true;
  bool _enableScheduleChangeReviews = true;
  bool _enableFighterCheckinAlerts = true;
  NotificationTemplateField _activeField = NotificationTemplateField.none;

  @override
  void dispose() {
    _schedTitleCtrl.dispose();
    _schedBodyCtrl.dispose();
    _changeApprovedTitleCtrl.dispose();
    _changeApprovedBodyCtrl.dispose();
    _changeRejectedTitleCtrl.dispose();
    _changeRejectedBodyCtrl.dispose();
    _schedTitleFocus.dispose();
    _schedBodyFocus.dispose();
    _changeApprovedTitleFocus.dispose();
    _changeApprovedBodyFocus.dispose();
    _changeRejectedTitleFocus.dispose();
    _changeRejectedBodyFocus.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _setActiveField(NotificationTemplateField field) {
    if (_activeField == field) return;
    setState(() => _activeField = field);
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
      _enableScheduleChangeReviews = settings.enableScheduleChangeReviews;
      _enableFighterCheckinAlerts = settings.enableFighterCheckinAlerts;
      _schedTitleCtrl.text = settings.scheduleUpdateTitleTemplate;
      _schedBodyCtrl.text = settings.scheduleUpdateBodyTemplate;
      _changeApprovedTitleCtrl.text =
          settings.scheduleChangeApprovedTitleTemplate;
      _changeApprovedBodyCtrl.text = settings.scheduleChangeApprovedBodyTemplate;
      _changeRejectedTitleCtrl.text =
          settings.scheduleChangeRejectedTitleTemplate;
      _changeRejectedBodyCtrl.text = settings.scheduleChangeRejectedBodyTemplate;
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
                          'Queues schedule_update notifications when schedules are created or edited.',
                        ),
                        value: _enableScheduleUpdates,
                        onChanged: (v) =>
                            setState(() => _enableScheduleUpdates = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable schedule change reviews'),
                        subtitle: const Text(
                          'Queues schedule_update notifications when change requests are approved or rejected.',
                        ),
                        value: _enableScheduleChangeReviews,
                        onChanged: (v) =>
                            setState(() => _enableScheduleChangeReviews = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable fighter check-in alerts'),
                        subtitle: const Text(
                          'Shows a dialog, alert sound, and browser notification when a fighter checks in.',
                        ),
                        value: _enableFighterCheckinAlerts,
                        onChanged: (v) =>
                            setState(() => _enableFighterCheckinAlerts = v),
                      ),
                      SizedBox(height: AppLayout.mediumGap(context)),
                      NotificationTemplateEditor(
                        sectionTitle: 'Schedule update templates (optional)',
                        sectionSubtitle:
                            'Used when creating or editing fighter schedules.',
                        titleLabel: 'Schedule update title template',
                        bodyLabel: 'Schedule update body template',
                        titleHelper:
                            'Placeholders: {fighterName} {date} {startTime} {endTime} {locationName} {contactName} {recurrence}',
                        bodyHelper:
                            'Placeholders: {fighterName} {date} {startTime} {endTime} {locationName} {contactName} {recurrence} {notes}',
                        placeholderTokens:
                            ScheduleNotificationPlaceholders.scheduleUpdate,
                        titleController: _schedTitleCtrl,
                        bodyController: _schedBodyCtrl,
                        titleFieldKey: NotificationTemplateField.scheduleUpdateTitle,
                        bodyFieldKey: NotificationTemplateField.scheduleUpdateBody,
                        titleFocusNode: _schedTitleFocus,
                        bodyFocusNode: _schedBodyFocus,
                        activeField: _activeField,
                        onActiveFieldChanged: _setActiveField,
                        defaultTitleTemplate:
                            NotificationMessageComposer.defaultScheduleUpdateTitle,
                        defaultBodyTemplate:
                            NotificationMessageComposer.defaultScheduleUpdateBody,
                      ),
                      SizedBox(height: AppLayout.sectionGap(context)),
                      NotificationTemplateEditor(
                        sectionTitle: 'Change request — approved',
                        sectionSubtitle:
                            'Sent to the fighter when you approve a schedule change request.',
                        titleLabel: 'Approved title template',
                        bodyLabel: 'Approved body template',
                        titleHelper:
                            'Placeholders: {fighterName} {requestType} {adminNotes} {date} {startTime} {endTime} {locationName} {proposedLocationText}',
                        bodyHelper:
                            'Placeholders: {fighterName} {requestType} {adminNotes} {date} {startTime} {endTime} {locationName} {proposedLocationText}',
                        placeholderTokens:
                            ScheduleNotificationPlaceholders.scheduleChangeReview,
                        titleController: _changeApprovedTitleCtrl,
                        bodyController: _changeApprovedBodyCtrl,
                        titleFieldKey: NotificationTemplateField.changeApprovedTitle,
                        bodyFieldKey: NotificationTemplateField.changeApprovedBody,
                        titleFocusNode: _changeApprovedTitleFocus,
                        bodyFocusNode: _changeApprovedBodyFocus,
                        activeField: _activeField,
                        onActiveFieldChanged: _setActiveField,
                        defaultTitleTemplate: NotificationMessageComposer
                            .defaultScheduleChangeApprovedTitle,
                        defaultBodyTemplate: NotificationMessageComposer
                            .defaultScheduleChangeApprovedBody,
                      ),
                      SizedBox(height: AppLayout.sectionGap(context)),
                      NotificationTemplateEditor(
                        sectionTitle: 'Change request — rejected',
                        sectionSubtitle:
                            'Sent to the fighter when you reject a schedule change request.',
                        titleLabel: 'Rejected title template',
                        bodyLabel: 'Rejected body template',
                        titleHelper:
                            'Placeholders: {fighterName} {requestType} {adminNotes} {date} {startTime} {endTime} {locationName} {proposedLocationText}',
                        bodyHelper:
                            'Placeholders: {fighterName} {requestType} {adminNotes} {date} {startTime} {endTime} {locationName} {proposedLocationText}',
                        placeholderTokens:
                            ScheduleNotificationPlaceholders.scheduleChangeReview,
                        titleController: _changeRejectedTitleCtrl,
                        bodyController: _changeRejectedBodyCtrl,
                        titleFieldKey: NotificationTemplateField.changeRejectedTitle,
                        bodyFieldKey: NotificationTemplateField.changeRejectedBody,
                        titleFocusNode: _changeRejectedTitleFocus,
                        bodyFocusNode: _changeRejectedBodyFocus,
                        activeField: _activeField,
                        onActiveFieldChanged: _setActiveField,
                        defaultTitleTemplate: NotificationMessageComposer
                            .defaultScheduleChangeRejectedTitle,
                        defaultBodyTemplate: NotificationMessageComposer
                            .defaultScheduleChangeRejectedBody,
                      ),
                      SizedBox(height: AppLayout.mediumGap(context)),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: mutation.isSaving
                                ? null
                                : () async {
                                    final base = settings ??
                                        NotificationSettings.defaults();
                                    final next = base.copyWith(
                                      enableAdminMessages: _enableAdminMessages,
                                      enableScheduleUpdates: _enableScheduleUpdates,
                                      enableScheduleChangeReviews:
                                          _enableScheduleChangeReviews,
                                      enableFighterCheckinAlerts:
                                          _enableFighterCheckinAlerts,
                                      scheduleUpdateTitleTemplate:
                                          _schedTitleCtrl.text,
                                      scheduleUpdateBodyTemplate: _schedBodyCtrl.text,
                                      scheduleChangeApprovedTitleTemplate:
                                          _changeApprovedTitleCtrl.text,
                                      scheduleChangeApprovedBodyTemplate:
                                          _changeApprovedBodyCtrl.text,
                                      scheduleChangeRejectedTitleTemplate:
                                          _changeRejectedTitleCtrl.text,
                                      scheduleChangeRejectedBodyTemplate:
                                          _changeRejectedBodyCtrl.text,
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

