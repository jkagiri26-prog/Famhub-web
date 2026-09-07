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
import '../entities/business_listing.dart';
import '../entities/business_profile.dart';
import '../entities/business_transaction.dart';
import '../entities/inventory_item.dart';
import '../entities/purchase_order.dart';
import '../entities/sales_order.dart';
import '../entities/sales_order_line.dart';

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

  /// Fetch purchase orders for the given business entity (read-only).
  ///
  /// Reads the canonical `commerce.purchase_orders`. Because that table
  /// has NO buyer/business entity column, procurement is scoped to the
  /// active business by resolving its people scope (owner +
  /// `core.entity_members`) and reading orders whose `created_by`
  /// belongs to that scope. Supplier display names are enriched from
  /// `commerce.business_profiles`. No client-supplied `user_id` is sent.
  Future<List<PurchaseOrder>> fetchPurchaseOrders(String entityId);

  /// Fetch sales orders for the given business entity (read-only).
  ///
  /// Reads the canonical `commerce.orders`. Orders are associated with a
  /// business through the verified `supplier_id` FK →
  /// `commerce.business_profiles`, and the seller business of record for
  /// an entity is that entity's own business profiles. Orders are
  /// therefore scoped by `supplier_id ∈ { active entity's business
  /// profiles }`. Buyer names are enriched from `users.profiles`
  /// (best-effort, RLS-bound). No client-supplied `user_id` is sent.
  Future<List<SalesOrder>> fetchSalesOrders(String entityId);

  /// Fetch item lines for one sales order (read-only).
  ///
  /// Reads the canonical `commerce.order_items`, related to its parent
  /// order via the verified `order_id` FK. Item labels are enriched from
  /// `core.item_variants`/`core.units`; `product_id` is NOT treated as a
  /// relationship (no FK exists).
  Future<List<SalesOrderLine>> fetchOrderItems(String orderId);

  /// Fetch listings for the given business entity (read/management
  /// visibility only).
  ///
  /// Delegates to the existing Marketplace repository (composition) and
  /// scopes by the verified `marketplace.listings.entity_id` →
  /// `core.entities` seller relationship — never from the client.
  /// Variant display names are enriched from `core.item_variants`.
  /// No new listing logic/catalog is created in Business Hub.
  Future<List<BusinessListing>> fetchListings(String entityId);

  /// Fetch payment transactions for the given business entity
  /// (read-only).
  ///
  /// Reads the canonical, currency-aware `commerce.transactions`, scoped
  /// by the verified `supplier_id` FK → `commerce.business_profiles` of
  /// the active business (the business of record). Amounts are shown per
  /// row with their real currency code; no totals are computed here.
  Future<List<BusinessTransaction>> fetchTransactions(String entityId);
}
