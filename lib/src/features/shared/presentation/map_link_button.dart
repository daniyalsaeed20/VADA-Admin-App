import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/localization_x.dart';

/// Icon button that opens the given coordinates in Google Maps.
///
/// When either [latitude] or [longitude] is missing, the button is shown
/// disabled so the admin can see at a glance which rows can't be mapped.
class MapLinkButton extends StatelessWidget {
  const MapLinkButton({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double? latitude;
  final double? longitude;

  bool get _hasCoordinates => latitude != null && longitude != null;

  static Uri googleMapsUri(double latitude, double longitude) {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    if (!_hasCoordinates) {
      return IconButton(
        tooltip: loc.tr('common.noCoordinates'),
        onPressed: null,
        icon: const Icon(Icons.location_off_outlined),
      );
    }
    return IconButton(
      tooltip: loc.tr('common.viewOnMap'),
      onPressed: () => _open(context),
      icon: const Icon(Icons.map_outlined),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = googleMapsUri(latitude!, longitude!);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }
}
