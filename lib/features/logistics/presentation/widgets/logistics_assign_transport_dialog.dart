import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/logistics_dashboard_provider.dart';
import '../../application/providers/logistics_shipment_provider.dart';
import '../../domain/models/logistics_detail_models.dart';
import '../../infrastructure/services/logistics_action_error_mapper.dart';

/// Transport administration input for `logistics.assign_transport`.
///
/// Collects provider / driver / vehicle / notes and hands them to the
/// backend RPC. The dialog never decides permissions — if the backend
/// rejects the action the failure is surfaced as safe copy.
class LogisticsAssignTransportDialog extends ConsumerStatefulWidget {
  final String shipmentId;

  const LogisticsAssignTransportDialog({
    super.key,
    required this.shipmentId,
  });

  /// Opens the dialog. Returns true when an assignment was created.
  static Future<bool> show(
    BuildContext context, {
    required String shipmentId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => LogisticsAssignTransportDialog(shipmentId: shipmentId),
    );
    return result == true;
  }

  @override
  ConsumerState<LogisticsAssignTransportDialog> createState() =>
      _LogisticsAssignTransportDialogState();
}

class _LogisticsAssignTransportDialogState
    extends ConsumerState<LogisticsAssignTransportDialog> {
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _providerId;
  String? _driverId;
  String? _vehicleId;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _providerController.dispose();
    _driverController.dispose();
    _vehicleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _providerValue =>
      (_providerId ?? _providerController.text).trim();
  String get _driverValue => (_driverId ?? _driverController.text).trim();
  String get _vehicleValue => (_vehicleId ?? _vehicleController.text).trim();

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_providerValue.isEmpty) {
      setState(() => _error = 'Select a transport provider.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(logisticsRepositoryProvider).assignTransport(
            shipmentId: widget.shipmentId,
            providerEntityId: _providerValue,
            driverProfileId: _driverValue.isEmpty ? null : _driverValue,
            vehicleId: _vehicleValue.isEmpty ? null : _vehicleValue,
            notes: _notesController.text.trim(),
          );

      ref.invalidate(logisticsShipmentDetailProvider(widget.shipmentId));
      ref.invalidate(logisticsShipmentsProvider);
      ref.invalidate(logisticsDashboardProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = describeAssignTransportError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(logisticsTransportOptionsProvider);
    final options = optionsAsync.value ?? LogisticsTransportOptions.empty;

    return AlertDialog(
      title: const Text('Assign transport'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.red.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              Text(
                'Shipment #${widget.shipmentId}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              if (options.providers.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _providerId,
                  decoration: const InputDecoration(
                    labelText: 'Transport provider *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final provider in options.providers)
                      DropdownMenuItem(
                        value: provider.id,
                        child: Text(
                          provider.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _providerId = value),
                )
              else
                TextField(
                  controller: _providerController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Transport provider entity id *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText: 'Required — the core.entities id of the '
                        'provider.',
                  ),
                ),

              const SizedBox(height: 16),

              if (options.drivers.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _driverId,
                  decoration: const InputDecoration(
                    labelText: 'Driver',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('No driver'),
                    ),
                    for (final driver in options.drivers)
                      DropdownMenuItem(
                        value: driver.id,
                        child: Text(
                          driver.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _driverId = value ?? ''),
                )
              else
                TextField(
                  controller: _driverController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Driver profile id (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

              const SizedBox(height: 16),

              if (options.vehicles.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _vehicleId,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('No vehicle'),
                    ),
                    for (final vehicle in options.vehicles)
                      DropdownMenuItem(
                        value: vehicle.id,
                        child: Text(
                          vehicle.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _vehicleId = value ?? ''),
                )
              else
                TextField(
                  controller: _vehicleController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle id (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

              const SizedBox(height: 16),

              TextField(
                controller: _notesController,
                enabled: !_isSubmitting,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: Text(_isSubmitting ? 'Assigning...' : 'Assign'),
        ),
      ],
    );
  }
}
