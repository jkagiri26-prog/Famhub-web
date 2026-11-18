import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/domain/models/contact_unlock_payment.dart';
import 'package:famhub_app/features/marketplace/domain/models/mpesa_phone.dart';

/// Buyer-facing contact-unlock payment and contact-reveal experience.
///
/// Seller contact is only requested when the backend reports a completed,
/// unexpired unlock. The client never calls the service-role confirmation RPC.
class ContactUnlockSection extends ConsumerStatefulWidget {
  final Listing listing;

  const ContactUnlockSection({super.key, required this.listing});

  @override
  ConsumerState<ContactUnlockSection> createState() =>
      _ContactUnlockSectionState();
}

class _ContactUnlockSectionState extends ConsumerState<ContactUnlockSection> {
  static const Duration _pollInterval = Duration(seconds: 5);
  static const int _maxPollAttempts = 12;

  bool _isSubmitting = false;
  bool _providerUnavailable = false;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  final TextEditingController _phoneController = TextEditingController();

  Listing get _listing => widget.listing;

  @override
  void dispose() {
    _stopPolling();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isPending(ContactUnlockStatus status) {
    return status.paymentStatus == 'pending' ||
        status.attemptStatus == 'created' ||
        status.attemptStatus == 'pending' ||
        status.attemptStatus == 'processing';
  }

  bool _isFailed(ContactUnlockStatus status) {
    return status.paymentStatus == 'failed' ||
        status.attemptStatus == 'failed' ||
        status.attemptStatus == 'cancelled' ||
        status.attemptStatus == 'expired';
  }

  @override
  Widget build(BuildContext context) {
    if (_listing.status != ListingStatus.active) {
      return const _NoticeCard(
        icon: Icons.lock_clock_outlined,
        title: 'Contact unlock unavailable',
        message: 'This listing is not active, so seller contact cannot be '
            'unlocked.',
      );
    }

    if (_listing.contactVisibility != 'locked') {
      return const SizedBox.shrink();
    }

    if (_providerUnavailable) {
      return _UnlockCard(
        title: 'M-Pesa temporarily unavailable',
        message: 'Your payment request was created, but M-Pesa initiation is '
            'not available right now. No payment was taken. Try again shortly.',
        buttonLabel: 'Try again',
        isSubmitting: _isSubmitting,
        onPressed: _startUnlock,
      );
    }

    final statusAsync = ref.watch(contactUnlockStatusProvider(_listing.id));

    return statusAsync.when(
      loading: () => const _LoadingCard(),
      error: (error, _) {
        _stopPolling();
        return _ErrorCard(
          message: 'Could not load unlock status.',
          onRetry: () {
            ref.invalidate(contactUnlockStatusProvider(_listing.id));
          },
        );
      },
      data: (status) {
        if (status != null && status.isUnlocked) {
          _stopPolling();
          return _UnlockedContactCard(listingId: _listing.id);
        }
        if (status != null && _isPending(status)) {
          _ensurePolling();
          return _PendingCard(
            onRefresh: () {
              _pollAttempts = 0;
              _ensurePolling();
              ref.invalidate(contactUnlockStatusProvider(_listing.id));
              ref.invalidate(sellerContactForUnlockProvider(_listing.id));
            },
          );
        }
        if (status != null && _isFailed(status)) {
          _stopPolling();
          return _UnlockCard(
            title: 'Payment was not completed',
            message: 'The previous M-Pesa request did not complete. You can '
                'try again.',
            buttonLabel: 'Try again',
            isSubmitting: _isSubmitting,
            onPressed: _startUnlock,
          );
        }
        _stopPolling();
        return _UnlockCard(
          title: 'Unlock seller contact',
          message: 'Pay securely with M-Pesa to reveal the seller’s phone '
              'and email. Seller contact stays hidden until Finance confirms '
              'the payment.',
          buttonLabel: 'Unlock contact',
          isSubmitting: _isSubmitting,
          onPressed: _startUnlock,
        );
      },
    );
  }

  Future<void> _startUnlock() async {
    if (_isSubmitting) return;

    final phone = await _promptForPhone();
    if (phone == null || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _providerUnavailable = false;
    });
    try {
      final idempotencyKey =
          'contact-unlock:${_listing.id}:${DateTime.now().microsecondsSinceEpoch}';
      final payment = await ref
          .read(marketplaceProvider.notifier)
          .requestContactUnlockPayment(
            listingId: _listing.id,
            phone: phone,
            idempotencyKey: idempotencyKey,
          );

      if (!mounted) return;
      ref.invalidate(contactUnlockStatusProvider(_listing.id));
      ref.invalidate(sellerContactForUnlockProvider(_listing.id));
      _ensurePolling();

      _providerUnavailable = false;
      final message = payment.isAlreadyUnlocked
          ? 'This contact is already unlocked.'
          : 'Payment request created. Check your phone for the M-Pesa prompt.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on ContactUnlockProviderUnavailable {
      if (!mounted) return;
      setState(() => _providerUnavailable = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'M-Pesa is temporarily unavailable. No payment was taken; '
            'please try again shortly.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _ensurePolling() {
    if (_pollTimer != null) return;
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(_pollInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        _pollTimer = null;
        return;
      }
      if (_pollAttempts >= _maxPollAttempts) {
        _stopPolling();
        return;
      }
      _pollAttempts++;
      ref.invalidate(contactUnlockStatusProvider(_listing.id));
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollAttempts = 0;
  }

  Future<String?> _promptForPhone() async {
    final formKey = GlobalKey<FormState>();
    _phoneController.clear();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('M-Pesa phone number'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '07XX XXX XXX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                if (normalizeKenyanMpesaPhone(value ?? '') == null) {
                  return 'Enter a valid Kenyan M-Pesa number.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                final normalized =
                    normalizeKenyanMpesaPhone(_phoneController.text);
                Navigator.of(dialogContext).pop(normalized);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return result;
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('Listing is not eligible')) {
      return 'This listing is no longer available for contact unlock.';
    }
    if (text.contains('No valid active contact-unlock price')) {
      return 'Contact unlock is not currently available for this listing.';
    }
    if (text.contains('Unauthorized') || text.contains('42501')) {
      return 'You do not have permission to unlock this contact.';
    }
    return 'Could not start the contact unlock. Please try again.';
  }
}

class _UnlockCard extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final bool isSubmitting;
  final VoidCallback onPressed;

  const _UnlockCard({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.isSubmitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.lock_open_outlined,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isSubmitting ? null : onPressed,
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.payment_outlined),
            label: Text(isSubmitting ? 'Starting…' : buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final VoidCallback onRefresh;

  const _PendingCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.hourglass_top_outlined,
      title: 'Payment pending',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check your phone for the M-Pesa prompt. Seller contact will be '
            'revealed automatically after Finance confirms payment.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Refresh status'),
          ),
        ],
      ),
    );
  }
}

class _UnlockedContactCard extends ConsumerWidget {
  final String listingId;

  const _UnlockedContactCard({required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactAsync = ref.watch(sellerContactForUnlockProvider(listingId));

    return contactAsync.when(
      loading: () => const _LoadingCard(message: 'Loading seller contact…'),
      error: (error, _) => _ErrorCard(
        message: 'Payment is confirmed, but seller contact could not be loaded.',
        onRetry: () {
          ref.invalidate(sellerContactForUnlockProvider(listingId));
        },
      ),
      data: (contact) {
        final rows = <Widget>[
          if (contact.contactPerson?.trim().isNotEmpty == true)
            _ContactRow(
              icon: Icons.person_outline,
              label: 'Contact person',
              value: contact.contactPerson!,
            ),
          if (contact.businessName?.trim().isNotEmpty == true)
            _ContactRow(
              icon: Icons.storefront_outlined,
              label: 'Business',
              value: contact.businessName!,
            ),
          if (contact.phone?.trim().isNotEmpty == true)
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: contact.phone!,
            ),
          if (contact.email?.trim().isNotEmpty == true)
            _ContactRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: contact.email!,
            ),
          if (contact.physicalAddress?.trim().isNotEmpty == true)
            _ContactRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: contact.physicalAddress!,
            ),
        ];

        return _SectionCard(
          icon: Icons.verified_user_outlined,
          title: 'Seller contact unlocked',
          child: rows.isEmpty
              ? const Text('No seller contact details are available.')
              : Column(children: rows),
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: icon,
      title: title,
      child: Text(message, style: TextStyle(color: Colors.grey.shade700)),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String message;

  const _LoadingCard({this.message = 'Loading unlock status…'});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.lock_outline,
      title: 'Contact unlock',
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(message),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.error_outline,
      title: 'Contact unlock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
