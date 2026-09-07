/// ============================================================
/// BUSINESS HUB — MORE TAB (BUSINESS ADMINISTRATION)
/// ============================================================
///
/// Business-level management/navigation area. Not another dashboard and
/// not the global Settings/Finance module.
///
/// Read-only this phase:
///   - Business Profile (commerce.business_profiles) — verified fields
///   - Team & Members (core.entity_members) — member list the current
///     user is authorized to see
///
/// Intentionally unavailable (future capabilities, no fake screens):
///   - Locations & Facilities (no existing business-location contract;
///     `core.locations` is geography reference data, not business-owned)
///   - Business Settings (no business-specific settings contract; global
///     Settings is not duplicated)
///
/// Business creation is NOT offered — the generic entity-creation
/// backend contract is unresolved; the no-business state already says
/// onboarding comes later.
///
/// Capability/context driven: sections appear based on existing
/// contracts — never on `businessType == ...` branching.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/application/providers/active_business_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/members_provider.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_member.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_profile.dart';

class BusinessHubMoreTab extends ConsumerWidget {
  const BusinessHubMoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    if (active == null) {
      return _infoCard(
        context,
        icon: Icons.business_outlined,
        title: 'No active business',
        message: 'Select a business to manage it here. Creating and '
            'linking businesses will be available in a later phase.',
      );
    }

    final profileAsync = ref.watch(businessProfileProvider(active.id));
    final membersAsync = ref.watch(activeBusinessMembersProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionLabel(context, 'Business Profile'),
        const SizedBox(height: 8),
        profileAsync.when(
          loading: () => const _SlimLoader(),
          error: (_, __) => _infoCard(
            context,
            icon: Icons.storefront_outlined,
            title: 'Could not load profile',
            message: 'Try again in a moment.',
          ),
          data: (BusinessProfile? profile) {
            if (profile == null) {
              return _infoCard(
                context,
                icon: Icons.storefront_outlined,
                title: 'No business profile yet',
                message: 'Seller/business profile onboarding lands in a '
                    'later phase. Nothing is editable here yet.',
              );
            }
            return _ProfileCard(profile: profile, businessName: active.name);
          },
        ),

        const SizedBox(height: 20),
        _sectionLabel(context, 'Team & Members'),
        const SizedBox(height: 8),
        membersAsync.when(
          loading: () => const _SlimLoader(),
          error: (_, __) => _infoCard(
            context,
            icon: Icons.group_outlined,
            title: 'Could not load members',
            message: 'Membership is not visible at the moment.',
          ),
          data: (members) {
            if (members.isEmpty) {
              return _infoCard(
                context,
                icon: Icons.group_outlined,
                title: 'No team members yet',
                message: 'Members of this business appear here once they '
                    'are linked (read-only).',
              );
            }
            return Column(
              children: [
                for (final member in members) _MemberRow(member: member),
              ],
            );
          },
        ),

        const SizedBox(height: 20),
        _sectionLabel(context, 'More capabilities'),
        const SizedBox(height: 8),
        _futureItem(
          context,
          icon: Icons.location_on_outlined,
          title: 'Locations & Facilities',
          message: 'Business facilities/locations will appear here once a '
              'canonical contract is available.',
        ),
        const SizedBox(height: 8),
        _futureItem(
          context,
          icon: Icons.settings_outlined,
          title: 'Business Settings',
          message: 'Business-specific settings will live here later. This '
              'does not replace the global Settings module.',
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 0.6,
          ),
    );
  }

  Widget _futureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Soon',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: Colors.grey.shade500),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// PROFILE CARD (read-only, verified fields)
/// ============================================================
class _ProfileCard extends StatelessWidget {
  final BusinessProfile profile;
  final String businessName;

  const _ProfileCard({required this.profile, required this.businessName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verified = profile.isVerified;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.business_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      verified
                          ? 'Verified seller profile'
                          : 'Verification: ${_statusLabel(profile.verificationStatus)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: verified
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _field('Business', businessName),
          if (profile.entityType != null && profile.entityType!.isNotEmpty)
            _field('Profile type', _capitalize(profile.entityType!)),
          if (profile.contactPerson != null && profile.contactPerson!.isNotEmpty)
            _field('Contact person', profile.contactPerson!),
          if (profile.phone != null && profile.phone!.isNotEmpty)
            _field('Phone', profile.phone!),
          if (profile.email != null && profile.email!.isNotEmpty)
            _field('Email', profile.email!),
          if (profile.rating != null) _field('Rating', '${profile.rating}'),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'suspended':
        return 'Suspended';
      default:
        return 'Pending';
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).replaceAll('_', ' ');
  }
}

/// ============================================================
/// MEMBER ROW (read-only)
/// ============================================================
class _MemberRow extends StatelessWidget {
  final BusinessMember member;

  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = member.label.isNotEmpty
        ? member.label.split(' ').where((p) => p.isNotEmpty).take(2).map(
            (p) => p[0].toUpperCase(),
          ).join()
        : '?';

    final traits = <String>[
      if (member.roleName != null && member.roleName!.isNotEmpty)
        member.roleName!,
      if (member.canManage) 'Can manage',
      if (member.canSell) 'Can sell',
      if (member.canReceivePayments) 'Payments',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (traits.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    traits.join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!member.isActive)
            Text(
              'Inactive',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _SlimLoader extends StatelessWidget {
  const _SlimLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
