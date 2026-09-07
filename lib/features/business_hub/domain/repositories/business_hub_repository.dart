/// ============================================================
/// BUSINESS HUB REPOSITORY (DOMAIN CONTRACT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/business_hub/domain/repositories/ = abstract contracts
///
/// Abstract repository contract for Business Hub.
/// Decoupled from Supabase — implementations live in infrastructure.
///
/// Backend schema identity is `commerce` (plus `core.entities` and
/// `core.entity_context_sessions`). Business Hub does NOT create a
/// parallel backend identity.
///
/// RLS/identity rules:
///   - Ownership (`owner_id`, `core.auth_user_id()`) is resolved
///     server-side. The client never sends a user id or entity id to
///     claim ownership.
///   - Reads return only rows the authenticated user may see.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../entities/business_entity.dart';
import '../entities/business_profile.dart';
import '../entities/inventory_item.dart';

abstract class BusinessHubRepository {
  /// List the business/entity records available to the current user.
  ///
  /// Reads `core.entities` (RLS-scoped server-side by
  /// `owner_id`/membership). No ownership claim is sent from the client.
  Future<List<BusinessEntity>> fetchMyBusinesses();

  /// Fetch the optional `commerce.business_profiles` record for an entity.
  ///
  /// Returns null when the entity has not onboarded a seller/business
  /// profile yet. `entity_id` is a lookup key for an entity the caller
  /// already can see — not an ownership claim.
  Future<BusinessProfile?> fetchBusinessProfile(String entityId);

  /// Fetch inventory rows for the given business entity.
  ///
  /// Reads the canonical `commerce.stock_registry` (plus
  /// `commerce.stock_movements` context later), scoped to the active
  /// business `entity_id`. Ownership stays server-side under RLS — the
  /// client never sends a `user_id`; `entityId` only scopes to a
  /// business the caller already can read. Display names are resolved
  /// from `core.item_variants` / `core.items` (no FK-embed reliance).
  Future<List<InventoryItem>> fetchInventory(String entityId);
}
