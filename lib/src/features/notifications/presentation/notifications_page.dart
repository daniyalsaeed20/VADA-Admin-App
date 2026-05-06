import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../fighters/domain/fighter.dart';
import '../../fighters/presentation/fighters_controller.dart';
import '../domain/admin_message_request.dart';
import 'notifications_controller.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _target = 'broadcast'; // broadcast | user
  String _targetUserId = '';

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final fightersAsync = ref.watch(fightersStreamProvider);
    final mutation = ref.watch(adminMessageMutationControllerProvider);
    final messagesAsync = ref.watch(adminMessagesStreamProvider);

    final fighters = fightersAsync.asData?.value ?? const <Fighter>[];
    final fighterNameById = {
      for (final f in fighters) f.uid: f.fullName,
    };

    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 980;

    return Padding(
      padding: EdgeInsets.all(AppLayout.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('nav.notifications'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: AppLayout.smallGap(context)),
          Text(
            'Admin messages (FCM via Cloud Functions)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (mutation.errorMessage != null)
            _Banner(message: mutation.errorMessage!, isError: true),
          if (mutation.successMessage != null)
            _Banner(message: mutation.successMessage!, isError: false),
          SizedBox(height: AppLayout.mediumGap(context)),
          Expanded(
            child: isNarrow
                ? ListView(
                    children: [
                      _ComposerCard(
                        formKey: _formKey,
                        titleController: _titleController,
                        bodyController: _bodyController,
                        target: _target,
                        onTargetChanged: (value) {
                          setState(() {
                            _target = value;
                            if (_target != 'user') {
                              _targetUserId = '';
                            }
                          });
                        },
                        fighters: fighters,
                        targetUserId: _targetUserId,
                        onTargetUserChanged: (uid) {
                          setState(() => _targetUserId = uid);
                        },
                        isLoading: mutation.isLoading,
                        onSend: () => _send(
                          target: _target,
                          targetUserId: _targetUserId,
                        ),
                      ),
                      SizedBox(height: AppLayout.mediumGap(context)),
                      _HistoryCard(
                        messagesAsync: messagesAsync,
                        fighterNameById: fighterNameById,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _ComposerCard(
                          formKey: _formKey,
                          titleController: _titleController,
                          bodyController: _bodyController,
                          target: _target,
                          onTargetChanged: (value) {
                            setState(() {
                              _target = value;
                              if (_target != 'user') {
                                _targetUserId = '';
                              }
                            });
                          },
                          fighters: fighters,
                          targetUserId: _targetUserId,
                          onTargetUserChanged: (uid) {
                            setState(() => _targetUserId = uid);
                          },
                          isLoading: mutation.isLoading,
                          onSend: () => _send(
                            target: _target,
                            targetUserId: _targetUserId,
                          ),
                        ),
                      ),
                      SizedBox(width: AppLayout.mediumGap(context)),
                      Expanded(
                        flex: 7,
                        child: _HistoryCard(
                          messagesAsync: messagesAsync,
                          fighterNameById: fighterNameById,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _send({
    required String target,
    required String targetUserId,
  }) async {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) {
      return;
    }
    if (target == 'user' && targetUserId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a fighter')),
      );
      return;
    }
    await ref.read(adminMessageMutationControllerProvider.notifier).send(
          title: _titleController.text,
          body: _bodyController.text,
          target: target,
          targetUserId: target == 'user' ? targetUserId : null,
        );
    if (mounted) {
      ref.read(adminMessageMutationControllerProvider.notifier).clearMessages();
      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _target = 'broadcast';
        _targetUserId = '';
      });
    }
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.formKey,
    required this.titleController,
    required this.bodyController,
    required this.target,
    required this.onTargetChanged,
    required this.fighters,
    required this.targetUserId,
    required this.onTargetUserChanged,
    required this.isLoading,
    required this.onSend,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final String target;
  final ValueChanged<String> onTargetChanged;
  final List<Fighter> fighters;
  final String targetUserId;
  final ValueChanged<String> onTargetUserChanged;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final sortedFighters = fighters.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    String? selectedName;
    if (targetUserId.isNotEmpty) {
      for (final f in sortedFighters) {
        if (f.uid == targetUserId) {
          selectedName = f.fullName;
          break;
        }
      }
    }

    final options = <_FighterOption>[
      ...sortedFighters.map((f) => _FighterOption(uid: f.uid, label: f.fullName)),
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compose',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'broadcast', label: Text('Broadcast')),
                  ButtonSegment(value: 'user', label: Text('Specific fighter')),
                ],
                selected: {target},
                onSelectionChanged: (value) => onTargetChanged(value.first),
              ),
              if (target == 'user') ...[
                SizedBox(height: AppLayout.smallGap(context)),
                Autocomplete<_FighterOption>(
                  initialValue: TextEditingValue(text: selectedName ?? ''),
                  displayStringForOption: (o) => o.label,
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) {
                      return options;
                    }
                    return options.where(
                      (o) => o.label.toLowerCase().contains(q),
                    );
                  },
                  onSelected: (o) => onTargetUserChanged(o.uid),
                  fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Fighter',
                        hintText: 'Search fighter',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: targetUserId.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  controller.clear();
                                  onTargetUserChanged('');
                                  focusNode.unfocus();
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                      onSubmitted: (_) => onSubmit(),
                    );
                  },
                ),
              ],
              SizedBox(height: AppLayout.mediumGap(context)),
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc.tr('fighters.required');
                  }
                  return null;
                },
              ),
              SizedBox(height: AppLayout.smallGap(context)),
              TextFormField(
                controller: bodyController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc.tr('fighters.required');
                  }
                  return null;
                },
              ),
              SizedBox(height: AppLayout.mediumGap(context)),
              Row(
                children: [
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: isLoading ? null : onSend,
                    icon: const Icon(Icons.send),
                    label: Text(isLoading ? loc.tr('common.loading') : 'Send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.messagesAsync,
    required this.fighterNameById,
  });

  final AsyncValue<List<AdminMessageRequest>> messagesAsync;
  final Map<String, String> fighterNameById;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppLayout.smallGap(context)),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('No messages yet'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: AppLayout.smallGap(context)),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final targetLabel = item.target == 'broadcast'
                          ? 'All fighters'
                          : (fighterNameById[item.targetUserId] ??
                              item.targetUserId ??
                              'Unknown');
                      return ListTile(
                        dense: true,
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.body}\nTo: $targetLabel',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: _StatusChip(status: item.status),
                      );
                    },
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSent = status == 'sent';
    final isFailed = status == 'failed';
    final fg = isSent
        ? AppColors.success
        : (isFailed ? scheme.error : scheme.onSurfaceVariant);
    final bg = fg.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});

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

class _FighterOption {
  const _FighterOption({required this.uid, required this.label});

  final String uid;
  final String label;
}

