import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../domain/approve_location_setup.dart';
import '../../domain/schedule_change_approve_helpers.dart';
import '../../domain/schedule_change_request.dart';
import '../../../locations/domain/location_lookup.dart';
import '../../../locations/domain/location_record.dart';
import '../../../shared/presentation/map_link_button.dart';

enum _LocationSetupMode { fighterLocation, createNew, useExisting }

/// Guided approve: create/link a testing location and optionally create a schedule row.
Future<ApproveSetupDialogResult?> showApproveScheduleChangeSetupDialog({
  required BuildContext context,
  required ScheduleChangeRequest request,
  required List<LocationRecord> locations,
}) {
  return showDialog<ApproveSetupDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ApproveScheduleChangeSetupDialog(
      request: request,
      locations: locations,
    ),
  );
}

class _ApproveScheduleChangeSetupDialog extends StatefulWidget {
  const _ApproveScheduleChangeSetupDialog({
    required this.request,
    required this.locations,
  });

  final ScheduleChangeRequest request;
  final List<LocationRecord> locations;

  @override
  State<_ApproveScheduleChangeSetupDialog> createState() =>
      _ApproveScheduleChangeSetupDialogState();
}

class _ApproveScheduleChangeSetupDialogState
    extends State<_ApproveScheduleChangeSetupDialog> {
  static const List<String> _types = ['testing', 'training', 'event'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  late _LocationSetupMode _mode;
  late String _selectedType;
  String? _existingLocationId;
  bool _createScheduleIfMissing = true;

  bool get _showLocationSection => needsApproveLocationSetup(widget.request);

  /// The point the fighter picked on the map in the mobile app, if any.
  MapCoordinates? get _fighterPin =>
      readPickedCoordinates(widget.request.requestedChanges);

  /// Map button for the directory location currently picked in the dropdown
  /// (mirrors the dropdown's fallback to the first location).
  Widget _selectedLocationMapButton() {
    final selected = findLocationRecord(
          locations: widget.locations,
          id: _existingLocationId,
        ) ??
        (widget.locations.isEmpty ? null : widget.locations.first);
    return MapLinkButton(
      latitude: selected?.latitude,
      longitude: selected?.longitude,
    );
  }
  bool get _showScheduleCreate => needsCreateScheduleOnApprove(widget.request);

  @override
  void initState() {
    super.initState();
    final changes = widget.request.requestedChanges;
    final name = readRequestedNewSiteName(changes);
    final addr = readRequestedNewSiteAddress(changes);
    if (name.isNotEmpty) {
      _nameController.text = name;
    }
    if (addr.isNotEmpty) {
      _addressController.text = addr;
    }
    final proposed = readScheduleField(
      changes,
      const ['proposedLocationText'],
    );
    if (name.isEmpty &&
        addr.isEmpty &&
        proposed.trim().isNotEmpty) {
      final parsed = parseProposedLocationText(proposed);
      _nameController.text = parsed.name;
      _addressController.text = parsed.address;
    }

    final requestedId = readScheduleField(
      changes,
      const ['locationId', 'selectedLocation'],
    );
    final ids = widget.locations.map((e) => e.id).toSet();
    if (requestedId.isNotEmpty && ids.contains(requestedId)) {
      _mode = _LocationSetupMode.useExisting;
      _existingLocationId = requestedId;
    } else if (_fighterPin != null) {
      _mode = _LocationSetupMode.fighterLocation;
      _existingLocationId =
          widget.locations.isEmpty ? null : widget.locations.first.id;
    } else if (readRequestedNewSiteSummary(changes).trim().isNotEmpty) {
      _mode = _LocationSetupMode.createNew;
      _existingLocationId =
          widget.locations.isEmpty ? null : widget.locations.first.id;
    } else {
      _mode = _LocationSetupMode.useExisting;
      _existingLocationId = widget.locations.isEmpty
          ? null
          : (requestedId.isNotEmpty && ids.contains(requestedId)
              ? requestedId
              : widget.locations.first.id);
    }

    _selectedType = 'testing';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Approve & set up location'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This request needs a directory location (and possibly a schedule row) '
                  'so the fighter’s app shows the correct testing site.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (_showLocationSection) ...[
                  SizedBox(height: AppLayout.mediumGap(context)),
                  SegmentedButton<_LocationSetupMode>(
                    segments: [
                      if (_fighterPin != null)
                        const ButtonSegment(
                          value: _LocationSetupMode.fighterLocation,
                          label: Text('Fighter’s pin'),
                          icon: Icon(Icons.push_pin_outlined),
                        ),
                      const ButtonSegment(
                        value: _LocationSetupMode.createNew,
                        label: Text('New site'),
                        icon: Icon(Icons.add_location_alt_outlined),
                      ),
                      const ButtonSegment(
                        value: _LocationSetupMode.useExisting,
                        label: Text('Existing'),
                        icon: Icon(Icons.place_outlined),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) {
                      setState(() {
                        _mode = s.first;
                        if (_mode == _LocationSetupMode.useExisting &&
                            widget.locations.isNotEmpty) {
                          final ids = widget.locations.map((e) => e.id).toSet();
                          if (_existingLocationId == null ||
                              !ids.contains(_existingLocationId)) {
                            _existingLocationId = widget.locations.first.id;
                          }
                        }
                      });
                    },
                  ),
                  SizedBox(height: AppLayout.mediumGap(context)),
                  if (_mode == _LocationSetupMode.fighterLocation) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            readRequestedNewSiteSummary(
                              widget.request.requestedChanges,
                            ),
                          ),
                        ),
                        MapLinkButton(
                          latitude: _fighterPin?.latitude,
                          longitude: _fighterPin?.longitude,
                        ),
                      ],
                    ),
                    SizedBox(height: AppLayout.smallGap(context)),
                    Text(
                      'The schedule will use the location the fighter picked '
                      'on the map. It won’t be added to the Locations directory.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ] else if (_mode == _LocationSetupMode.createNew) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Location name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: AppLayout.smallGap(context)),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Address / details',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    SizedBox(height: AppLayout.smallGap(context)),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedType),
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _types
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedType = v);
                        }
                      },
                    ),
                  ] else ...[
                    if (widget.locations.isEmpty)
                      Text(
                        'No locations in directory. Create one under Locations first.',
                        style: TextStyle(color: scheme.error),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          '${_mode}_${_existingLocationId}_${widget.locations.length}',
                        ),
                        initialValue: _existingLocationId != null &&
                                widget.locations.any((e) => e.id == _existingLocationId)
                            ? _existingLocationId
                            : (widget.locations.isEmpty
                                ? null
                                : widget.locations.first.id),
                        decoration: InputDecoration(
                          labelText: 'Testing location',
                          border: const OutlineInputBorder(),
                          suffixIcon: _selectedLocationMapButton(),
                        ),
                        items: widget.locations
                            .map(
                              (loc) => DropdownMenuItem(
                                value: loc.id,
                                child: Text(
                                  loc.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _existingLocationId = v),
                      ),
                  ],
                ],
                if (_showScheduleCreate) ...[
                  SizedBox(height: AppLayout.mediumGap(context)),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _createScheduleIfMissing,
                    onChanged: (v) => setState(
                      () => _createScheduleIfMissing = v ?? true,
                    ),
                    title: const Text('Create schedule entry if none is linked'),
                    subtitle: Text(
                      widget.request.scheduleId?.trim().isEmpty ?? true
                          ? 'Recommended so the fighter sees this test on their schedule.'
                          : 'Optional — a schedule is already linked.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Approve'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ApproveLocationSetup? locationSetup;
    if (_showLocationSection) {
      if (_mode == _LocationSetupMode.fighterLocation) {
        locationSetup = const ApproveLocationSetup.fighterLocation();
      } else if (_mode == _LocationSetupMode.createNew) {
        // Save the fighter's map pin (if any) as the new site's coordinates.
        final pin = _fighterPin;
        locationSetup = ApproveLocationSetup.create(
          locationName: _nameController.text,
          locationAddress: _addressController.text,
          locationType: _selectedType,
          latitude: pin?.latitude,
          longitude: pin?.longitude,
        );
      } else {
        final id = _existingLocationId?.trim() ?? '';
        if (id.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a location from the directory.')),
          );
          return;
        }
        locationSetup = ApproveLocationSetup.existing(existingLocationId: id);
      }
    }

    Navigator.pop(
      context,
      ApproveSetupDialogResult(
        locationSetup: locationSetup,
        createScheduleIfMissing: _createScheduleIfMissing,
      ),
    );
  }
}
