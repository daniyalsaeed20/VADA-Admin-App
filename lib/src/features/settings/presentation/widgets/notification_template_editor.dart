import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_layout.dart';
enum NotificationTemplateField {
  none,
  scheduleUpdateTitle,
  scheduleUpdateBody,
  changeApprovedTitle,
  changeApprovedBody,
  changeRejectedTitle,
  changeRejectedBody,
}

class NotificationTemplateEditor extends StatelessWidget {
  const NotificationTemplateEditor({
    super.key,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.titleLabel,
    required this.bodyLabel,
    required this.titleHelper,
    required this.bodyHelper,
    required this.placeholderTokens,
    required this.titleController,
    required this.bodyController,
    required this.titleFocusNode,
    required this.bodyFocusNode,
    required this.titleFieldKey,
    required this.bodyFieldKey,
    required this.activeField,
    required this.onActiveFieldChanged,
    required this.defaultTitleTemplate,
    required this.defaultBodyTemplate,
  });

  final String sectionTitle;
  final String sectionSubtitle;
  final String titleLabel;
  final String bodyLabel;
  final String titleHelper;
  final String bodyHelper;
  final List<String> placeholderTokens;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final FocusNode titleFocusNode;
  final FocusNode bodyFocusNode;
  final NotificationTemplateField titleFieldKey;
  final NotificationTemplateField bodyFieldKey;
  final NotificationTemplateField activeField;
  final ValueChanged<NotificationTemplateField> onActiveFieldChanged;
  final String defaultTitleTemplate;
  final String defaultBodyTemplate;

  void _insertPlaceholder(String token) {
    final ctrl = switch (activeField) {
      _ when activeField == titleFieldKey => titleController,
      _ when activeField == bodyFieldKey => bodyController,
      _ => null,
    };
    if (ctrl == null) {
      return;
    }

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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sectionTitle, style: Theme.of(context).textTheme.titleSmall),
        if (sectionSubtitle.isNotEmpty) ...[
          SizedBox(height: AppLayout.smallGap(context)),
          Text(
            sectionSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        SizedBox(height: AppLayout.smallGap(context)),
        _PlaceholderBar(
          titleFieldKey: titleFieldKey,
          bodyFieldKey: bodyFieldKey,
          activeField: activeField,
          placeholderTokens: placeholderTokens,
          onInsert: _insertPlaceholder,
          onCopy: (token) async {
            await Clipboard.setData(ClipboardData(text: token));
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied $token')),
            );
          },
        ),
        SizedBox(height: AppLayout.smallGap(context)),
        TextField(
          controller: titleController,
          focusNode: titleFocusNode,
          onTap: () => onActiveFieldChanged(titleFieldKey),
          decoration: InputDecoration(
            labelText: titleLabel,
            helperText: titleHelper,
            border: const OutlineInputBorder(),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () {
                  titleController.text = defaultTitleTemplate;
                  titleController.selection = TextSelection.collapsed(
                    offset: titleController.text.length,
                  );
                  onActiveFieldChanged(titleFieldKey);
                  titleFocusNode.requestFocus();
                },
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
          controller: bodyController,
          focusNode: bodyFocusNode,
          onTap: () => onActiveFieldChanged(bodyFieldKey),
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: bodyLabel,
            helperText: bodyHelper,
            border: const OutlineInputBorder(),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () {
                  bodyController.text = defaultBodyTemplate;
                  bodyController.selection = TextSelection.collapsed(
                    offset: bodyController.text.length,
                  );
                  onActiveFieldChanged(bodyFieldKey);
                  bodyFocusNode.requestFocus();
                },
                child: const Text('Use default'),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minHeight: 40,
              minWidth: 110,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderBar extends StatelessWidget {
  const _PlaceholderBar({
    required this.titleFieldKey,
    required this.bodyFieldKey,
    required this.activeField,
    required this.placeholderTokens,
    required this.onInsert,
    required this.onCopy,
  });

  final NotificationTemplateField titleFieldKey;
  final NotificationTemplateField bodyFieldKey;
  final NotificationTemplateField activeField;
  final List<String> placeholderTokens;
  final ValueChanged<String> onInsert;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActiveHere =
        activeField == titleFieldKey || activeField == bodyFieldKey;
    final activeLabel = !isActiveHere
        ? 'Select a title or body field in this section, then click a placeholder.'
        : 'Inserting into: ${activeField.name}';

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
            children: placeholderTokens.map((token) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActionChip(
                    label: Text(token),
                    onPressed: !isActiveHere ? null : () => onInsert(token),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () => onCopy(token),
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

/// Shared placeholder tokens for schedule-related notification templates.
abstract final class ScheduleNotificationPlaceholders {
  static const scheduleUpdate = [
    '{fighterName}',
    '{date}',
    '{startTime}',
    '{endTime}',
    '{locationName}',
    '{contactName}',
    '{recurrence}',
    '{notes}',
  ];

  static const scheduleChangeReview = [
    '{fighterName}',
    '{requestType}',
    '{adminNotes}',
    '{date}',
    '{startTime}',
    '{endTime}',
    '{locationName}',
    '{proposedLocationText}',
  ];
}
