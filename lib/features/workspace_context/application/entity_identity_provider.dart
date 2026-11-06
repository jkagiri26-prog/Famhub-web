/// ============================================================
/// ENTITY IDENTITY — owner + location for the active entity
/// ============================================================
///
/// Read-only enrichment for the page-level entity selector:
///   - owner name: core.entities.owner_id -> users.profiles
///   - location: business profile physical address / county hierarchy,
///     or the selected farm's village + location hierarchy
///
/// This does NOT participate in context/workspace selection. It only reads
/// presentation data for the currently active entity.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';

class EntityIdentity {
  final String? ownerName;
  final String? location;

  const EntityIdentity({this.ownerName, this.location});
}

/// Active entity + workspace context used to resolve identity details.
typedef EntityIdentityKey = ({
  String entityId,
  String? workspaceType,
  String? farmId,
  String? businessProfileId,
});

final entityIdentityProvider =
    FutureProvider.autoDispose.family<EntityIdentity, EntityIdentityKey>(
        (ref, key) async {
  if (key.entityId.isEmpty) return const EntityIdentity();

  final client = SupabaseService.instance.client;
  String? ownerName;
  String? location;

  // ── Owner of the entity (not the current user) ──
  try {
    final entity = await client
        .schema('core')
        .from('entities')
        .select('owner_id')
        .eq('id', key.entityId)
        .maybeSingle();
    final ownerId = entity?['owner_id']?.toString();
    if (ownerId != null && ownerId.isNotEmpty) {
      final profile = await client
          .schema('users')
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', ownerId)
          .maybeSingle();
      if (profile != null) {
        final name = [profile['first_name'], profile['last_name']]
            .map((v) => v?.toString().trim() ?? '')
            .where((v) => v.isNotEmpty)
            .join(' ');
        if (name.isNotEmpty) ownerName = name;
      }
    }
  } catch (_) {
    // RLS may hide the owner profile; fall through without an owner name.
  }

  // ── Entity/business/farm location ──
  try {
    if (key.workspaceType == 'farmer' &&
        key.farmId != null &&
        key.farmId!.isNotEmpty) {
      final farm = await client
          .schema('farm_management')
          .from('farms')
          .select('village, county_id, sub_county_id, ward_id')
          .eq('id', key.farmId!)
          .maybeSingle();
      location = await _locationLabel(
        client,
        farm,
        addressKey: 'village',
        subCountyKey: 'sub_county_id',
      );
    } else {
      final profileQuery = client
          .schema('commerce')
          .from('business_profiles')
          .select('physical_address, county_id, subcounty_id, ward_id');
      final profile = key.businessProfileId != null &&
              key.businessProfileId!.isNotEmpty
          ? await profileQuery
              .eq('id', key.businessProfileId!)
              .maybeSingle()
          : await profileQuery
              .eq('entity_id', key.entityId)
              .limit(1)
              .maybeSingle();
      location = await _locationLabel(
        client,
        profile,
        addressKey: 'physical_address',
        subCountyKey: 'subcounty_id',
      );
    }
  } catch (_) {
    // Location is optional; never block the selector on it.
  }

  return EntityIdentity(ownerName: ownerName, location: location);
});

Future<String?> _locationLabel(
  SupabaseClient client,
  Map<String, dynamic>? row, {
  required String addressKey,
  required String subCountyKey,
}) async {
  if (row == null) return null;

  final address = row[addressKey]?.toString().trim();
  if (address != null && address.isNotEmpty) return address;

  final ids = <String>[
    row['ward_id']?.toString() ?? '',
    row[subCountyKey]?.toString() ?? '',
    row['county_id']?.toString() ?? '',
  ].where((id) => id.isNotEmpty).toList();
  if (ids.isEmpty) return null;

  final response = await client
      .schema('core')
      .from('locations')
      .select('id, name')
      .inFilter('id', ids);
  final names = <String, String>{
    for (final r in (response as List).cast<Map<String, dynamic>>())
      if (r['id'] != null && r['name'] != null)
        r['id'].toString(): r['name'].toString(),
  };

  final parts = <String>[
    for (final id in ids)
      if ((names[id] ?? '').trim().isNotEmpty) names[id]!.trim(),
  ];
  return parts.isEmpty ? null : parts.join(', ');
}
