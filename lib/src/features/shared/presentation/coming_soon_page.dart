import 'package:flutter/material.dart';

import '../../../core/localization/localization_x.dart';
import '../../../core/theme/brand_theme.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    required this.titleKey,
    super.key,
  });

  final String titleKey;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  size: 44,
                  color: BrandTheme.vadaRed.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 14),
                Text(
                  loc.tr(titleKey),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.tr('common.comingSoon'),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
