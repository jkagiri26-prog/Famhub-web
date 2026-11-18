import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/subscription/application/providers/subscription_entitlements_provider.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_entitlements.dart';
import 'package:famhub_app/features/marketplace/domain/models/mpesa_phone.dart';
import 'package:famhub_app/features/subscription_billing/application/providers/subscription_purchase_provider.dart';
import 'package:famhub_app/features/subscription_billing/application/providers/subscription_centre_provider.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_purchase.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_centre_state.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';

enum SubscriptionCentreStage {
  ready,
  invalidPhone,
  creatingCycle,
  initiating,
  pending,
  processing,
  providerUnavailable,
  definitiveFailure,
  retry,
  active,
  expired,
  genericError,
}

class SubscriptionCentrePage extends ConsumerStatefulWidget {
  const SubscriptionCentrePage({super.key});

  @override
  ConsumerState<SubscriptionCentrePage> createState() =>
      _SubscriptionCentrePageState();
}

class _SubscriptionCentrePageState
    extends ConsumerState<SubscriptionCentrePage> {
  final _phoneController = TextEditingController();
  String? _selectedPlanId;
  SubscriptionPlan? _selectedPlan;
  String? _idempotencyKey;
  SubscriptionCentreStage _stage = SubscriptionCentreStage.ready;
  SubscriptionCentreState? _snapshot;
  Timer? _pollTimer;
  bool _submitting = false;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    try {
      final state = await ref
          .read(subscriptionCentreRepositoryProvider)
          .fetchState();
      if (!mounted) return;
      setState(() {
        _snapshot = state;
        if (state.hasActive) {
          _stage = SubscriptionCentreStage.active;
        } else if (state.pending != null) {
          _stage = SubscriptionCentreStage.pending;
        } else if (state.latest?.isExpired == true) {
          _stage = SubscriptionCentreStage.expired;
        }
      });
      if (state.pending != null && !state.hasActive) {
        _startPolling();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = SubscriptionCentreStage.genericError);
    }
  }

  Future<void> _onPayPressed() async {
    if (_submitting ||
        _stage == SubscriptionCentreStage.creatingCycle ||
        _stage == SubscriptionCentreStage.initiating ||
        _stage == SubscriptionCentreStage.pending ||
        _stage == SubscriptionCentreStage.processing) {
      return;
    }
    final phone = normalizeKenyanMpesaPhone(_phoneController.text);
    if (phone == null) {
      setState(() => _stage = SubscriptionCentreStage.invalidPhone);
      return;
    }
    final plan = _selectedPlan;
    if (plan == null) {
      setState(() => _stage = SubscriptionCentreStage.genericError);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm subscription'),
        content: Text(
          '${plan.planName}\n'
          '${plan.currency} ${plan.amount.toStringAsFixed(0)} / ${plan.billingCycle}\n'
          'M-Pesa number: $phone',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _purchase(phone: phone, planId: plan.planId);
  }

  Future<void> _purchase({
    required String phone,
    required String planId,
  }) async {
    setState(() {
      _submitting = true;
      _stage = SubscriptionCentreStage.creatingCycle;
    });

    try {
      final purchase = await ref
          .read(subscriptionPurchaseRepositoryProvider)
          .createOrReusePurchase(planId: planId);
      if (!mounted) return;

      if (purchase.isActive) {
        setState(() => _stage = SubscriptionCentreStage.processing);
        await _poll();
        return;
      }

      setState(() => _stage = SubscriptionCentreStage.initiating);
      final key =
          _idempotencyKey ?? 'subscription-${purchase.subscriptionCycleId}';
      _idempotencyKey = key;

      final initiation = await ref
          .read(subscriptionCentreRepositoryProvider)
          .initiatePayment(
            subscriptionCycleId: purchase.subscriptionCycleId,
            phone: phone,
            idempotencyKey: key,
          );

      if (!mounted) return;
      if (initiation.isSucceeded) {
        setState(() => _stage = SubscriptionCentreStage.processing);
        await _poll();
        _startPolling();
      } else {
        setState(() => _stage = SubscriptionCentreStage.pending);
        _startPolling();
      }
    } on SubscriptionProviderUnavailable {
      if (mounted) {
        setState(() => _stage = SubscriptionCentreStage.providerUnavailable);
      }
    } on SubscriptionPaymentRejected {
      _idempotencyKey = null;
      if (mounted) {
        setState(() => _stage = SubscriptionCentreStage.definitiveFailure);
      }
    } on SubscriptionOutcomeUnknown {
      if (mounted) {
        setState(() => _stage = SubscriptionCentreStage.processing);
        _startPolling();
      }
    } on SubscriptionCentreError {
      if (mounted) {
        setState(() => _stage = SubscriptionCentreStage.genericError);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _stage = SubscriptionCentreStage.genericError);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      _pollCount++;
      await _poll();
      if (_pollCount >= 24) {
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> _poll() async {
    try {
      final state = await ref
          .read(subscriptionCentreRepositoryProvider)
          .fetchState();
      if (!mounted) return;
      setState(() => _snapshot = state);
      if (state.hasActive) {
        _pollTimer?.cancel();
        setState(() => _stage = SubscriptionCentreStage.active);
        ref.invalidate(subscriptionCentreStateProvider);
        ref.invalidate(subscriptionEntitlementsProvider);
        ref.invalidate(contextProvider);
      } else if (state.pending != null) {
        setState(() => _stage = SubscriptionCentreStage.pending);
      } else if (state.latest?.isExpired == true) {
        setState(() => _stage = SubscriptionCentreStage.expired);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = SubscriptionCentreStage.genericError);
    }
  }

  bool get _canRetry =>
      _stage == SubscriptionCentreStage.providerUnavailable ||
      _stage == SubscriptionCentreStage.definitiveFailure ||
      _stage == SubscriptionCentreStage.genericError;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final stateAsync = ref.watch(subscriptionCentreStateProvider);
    final entitlements = ref
        .watch(subscriptionEntitlementsProvider)
        .asData
        ?.value;
    final state =
        _snapshot ?? stateAsync.value ?? SubscriptionCentreState.empty;
    final hasPlans = plansAsync.asData?.value.isNotEmpty == true;

    return ResponsiveWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const ModuleHeaderWidget(
              title: 'Subscription Centre',
              subtitle: 'One subscription across all Vunio workspaces',
            ),
            const SizedBox(height: 20),
            _CurrentSubscriptionCard(
              state: state,
              stage: _stage,
              entitlements: entitlements,
            ),
            if (_stage == SubscriptionCentreStage.providerUnavailable) ...[
              const SizedBox(height: 12),
              const _MessageCard(
                icon: Icons.cloud_off_outlined,
                color: Colors.orange,
                text:
                    'M-Pesa is temporarily unavailable. No payment was taken. Please try again shortly.',
              ),
            ],
            if (_stage == SubscriptionCentreStage.definitiveFailure) ...[
              const SizedBox(height: 12),
              const _MessageCard(
                icon: Icons.error_outline,
                color: Colors.redAccent,
                text:
                    'The payment was not completed. Your subscription is still inactive.',
              ),
            ],
            if (_stage == SubscriptionCentreStage.invalidPhone) ...[
              const SizedBox(height: 12),
              const _MessageCard(
                icon: Icons.phone_disabled_outlined,
                color: Colors.redAccent,
                text: 'Enter a valid Safaricom number, e.g. 0712 345 678.',
              ),
            ],
            if (_stage == SubscriptionCentreStage.genericError) ...[
              const SizedBox(height: 12),
              const _MessageCard(
                icon: Icons.error_outline,
                color: Colors.redAccent,
                text: 'We could not complete that request. Please try again.',
              ),
            ],
            if (_stage == SubscriptionCentreStage.creatingCycle ||
                _stage == SubscriptionCentreStage.initiating ||
                _stage == SubscriptionCentreStage.pending ||
                _stage == SubscriptionCentreStage.processing) ...[
              const SizedBox(height: 12),
              _MessageCard(
                icon: Icons.hourglass_top_outlined,
                color: Colors.blue,
                text: _stage == SubscriptionCentreStage.creatingCycle
                    ? 'Creating your subscription…'
                    : _stage == SubscriptionCentreStage.initiating
                    ? 'Starting M-Pesa…'
                    : _stage == SubscriptionCentreStage.processing
                    ? 'Processing payment. We will refresh your subscription automatically.'
                    : 'Waiting for M-Pesa confirmation. Do not pay again.',
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Subscription plans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            plansAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => const _MessageCard(
                icon: Icons.cloud_off_outlined,
                color: Colors.orange,
                text: 'Plans are temporarily unavailable. Please try again.',
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return const _MessageCard(
                    icon: Icons.inventory_2_outlined,
                    color: Colors.grey,
                    text: 'No subscription plans are available yet.',
                  );
                }
                return Column(
                  children: [
                    for (final plan in plans)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlanCard(
                          plan: plan,
                          selected: plan.planId == _selectedPlanId,
                          onTap: () => setState(() {
                            _selectedPlanId = plan.planId;
                            _selectedPlan = plan;
                            if (_stage ==
                                    SubscriptionCentreStage.genericError ||
                                _stage ==
                                    SubscriptionCentreStage.invalidPhone) {
                              _stage = SubscriptionCentreStage.ready;
                            }
                          }),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (!state.hasActive && hasPlans) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'M-Pesa phone number',
                  hintText: '0712 345 678',
                  prefixIcon: Icon(Icons.phone_iphone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _submitting ||
                          _stage == SubscriptionCentreStage.creatingCycle ||
                          _stage == SubscriptionCentreStage.initiating ||
                          _stage == SubscriptionCentreStage.pending ||
                          _stage == SubscriptionCentreStage.processing
                      ? null
                      : _onPayPressed,
                  child: Text(_canRetry ? 'Try again' : 'Pay with M-Pesa'),
                ),
              ),
            ],
            if (state.history.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Subscription history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final entry in state.history) _HistoryTile(entry: entry),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  const _CurrentSubscriptionCard({
    required this.state,
    required this.stage,
    required this.entitlements,
  });

  final SubscriptionCentreState state;
  final SubscriptionCentreStage stage;
  final SubscriptionEntitlements? entitlements;

  @override
  Widget build(BuildContext context) {
    final active = state.active;
    final pending = state.pending;
    if (active != null) {
      return _ActiveSubscriptionCard(entry: active, entitlements: entitlements);
    }
    if (pending != null) {
      return _MessageCard(
        icon: Icons.hourglass_top_outlined,
        color: Colors.blue,
        text:
            '${pending.planName} is pending payment · ${_frequencyLabel(pending.billingCycle)} · ${pending.currency} ${pending.amount.toStringAsFixed(0)}',
      );
    }
    if (stage == SubscriptionCentreStage.expired ||
        state.latest?.isExpired == true) {
      return const _MessageCard(
        icon: Icons.event_busy_outlined,
        color: Colors.orange,
        text:
            'Your subscription has expired. Choose a subscription plan to renew.',
      );
    }
    return const _MessageCard(
      icon: Icons.workspace_premium_outlined,
      color: Colors.blueGrey,
      text:
          'No active subscription. Choose a subscription plan to get started.',
    );
  }
}

class _ActiveSubscriptionCard extends StatelessWidget {
  const _ActiveSubscriptionCard({
    required this.entry,
    required this.entitlements,
  });

  final SubscriptionCentreEntry entry;
  final SubscriptionEntitlements? entitlements;

  @override
  Widget build(BuildContext context) {
    final capabilities =
        entitlements?.capabilities.toList(growable: false) ?? const <String>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Your subscription is active',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow('Plan', entry.planName),
          _InfoRow('Frequency', _frequencyLabel(entry.billingCycle)),
          _InfoRow(
            'Price',
            '${entry.currency} ${entry.amount.toStringAsFixed(0)}',
          ),
          _InfoRow(
            'Current period',
            '${_date(entry.activeStart ?? entry.periodStart)} – ${_date(entry.activeEnd ?? entry.periodEnd)}',
          ),
          _InfoRow(
            'Status',
            entry.isActive ? 'Active' : (entry.activeStatus ?? 'Unknown'),
          ),
          _InfoRow(
            'Billing',
            entry.billingOwnerType == 'entity'
                ? 'Entity billing'
                : 'Individual billing',
          ),
          const SizedBox(height: 10),
          const Text(
            'Enabled capabilities',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (capabilities.isEmpty)
            Text(
              entitlements == null
                  ? 'Capabilities are being verified.'
                  : 'No paid capabilities are currently enabled.',
              style: TextStyle(color: Colors.grey.shade700),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final capability in capabilities)
                  Chip(
                    label: Text(capability),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final features = plan.features.keys.take(8).toList(growable: false);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.planName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.currency} ${plan.amount.toStringAsFixed(0)} / ${plan.billingCycle}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (features.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final feature in features)
                          Chip(
                            label: Text(feature),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final SubscriptionCentreEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text(entry.planName),
      subtitle: Text(
        '${_date(entry.periodStart)} – ${_date(entry.periodEnd)} · ${entry.cycleStatus}',
      ),
      trailing: Text(entry.currency),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _frequencyLabel(String value) {
  switch (value) {
    case 'monthly':
      return 'Monthly';
    case 'quarterly':
      return 'Quarterly';
    case 'yearly':
      return 'Yearly';
    default:
      return value.isEmpty ? 'Unknown' : value;
  }
}

String _date(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
