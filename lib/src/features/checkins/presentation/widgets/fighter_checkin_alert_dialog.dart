import 'package:flutter/material.dart';

import '../../../../core/audio/checkin_alert_tone.dart';
import '../../../../core/theme/app_layout.dart';
import '../../domain/checkin_record.dart';

class FighterCheckinAlertDialog extends StatefulWidget {
  const FighterCheckinAlertDialog({
    super.key,
    required this.fighterName,
    required this.record,
    required this.timeLabel,
    required this.titleText,
    required this.dismissLabel,
    required this.viewLabel,
    required this.timeCaption,
    required this.accuracyCaption,
    required this.labelCaption,
    required this.onView,
  });

  final String fighterName;
  final CheckinRecord record;
  final String timeLabel;
  final String titleText;
  final String dismissLabel;
  final String viewLabel;
  final String timeCaption;
  final String accuracyCaption;
  final String labelCaption;
  final VoidCallback onView;

  @override
  State<FighterCheckinAlertDialog> createState() =>
      _FighterCheckinAlertDialogState();
}

class _FighterCheckinAlertDialogState extends State<FighterCheckinAlertDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    // Retry tone when dialog opens (helps if Firestore fired before audio unlocked).
    playCheckinAlertTone();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accuracy = widget.record.accuracyMeters;
    final accuracyText = accuracy == null
        ? '—'
        : '${accuracy.toStringAsFixed(0)} m';
    final labelText =
        (widget.record.label ?? '').trim().isEmpty ? '—' : widget.record.label!;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppLayout.cardPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                          CurvedAnimation(
                            parent: _pulse,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: scheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                      ),
                      SizedBox(width: AppLayout.mediumGap(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.titleText,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.fighterName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppLayout.mediumGap(context)),
                  _InfoTile(
                    icon: Icons.schedule_outlined,
                    label: widget.timeCaption,
                    value: widget.timeLabel.isEmpty ? '—' : widget.timeLabel,
                  ),
                  SizedBox(height: AppLayout.smallGap(context)),
                  _InfoTile(
                    icon: Icons.gps_fixed_outlined,
                    label: widget.accuracyCaption,
                    value: accuracyText,
                  ),
                  if (labelText != '—') ...[
                    SizedBox(height: AppLayout.smallGap(context)),
                    _InfoTile(
                      icon: Icons.place_outlined,
                      label: widget.labelCaption,
                      value: labelText,
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppLayout.cardPadding(context),
                AppLayout.smallGap(context),
                AppLayout.cardPadding(context),
                AppLayout.cardPadding(context),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(widget.dismissLabel),
                    ),
                  ),
                  SizedBox(width: AppLayout.smallGap(context)),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onView();
                      },
                      icon: const Icon(Icons.gps_fixed_outlined),
                      label: Text(widget.viewLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
