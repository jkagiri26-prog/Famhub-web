/// ============================================================
/// SUPABASE SPATIAL REPOSITORY — BACKEND IMPLEMENTATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/infrastructure/ = spatial data access
///
/// Supabase-backed implementation of SpatialRepository.
/// This is the ONLY module that communicates with the backend
/// spatial tables. No other module should call Supabase.
///
/// ✅ Responsibilities:
///   - Implement SpatialRepository using Supabase client
///   - Map between backend JSON responses and domain models
///   - Handle errors gracefully with typed failures
///
/// ❌ Does NOT:
///   - Import Flutter UI
///   - Contain business logic
///   - Contain state
///   - Be consumed directly by feature modules
/// ============================================================
library;

import 'package:famhub_app/core/spatial/domain/spatial_asset.dart';
import 'package:famhub_app/core/spatial/domain/spatial_boundary.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_session.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_point.dart';
import 'package:famhub_app/core/spatial/domain/spatial_overlap.dart';
import 'package:famhub_app/core/spatial/infrastructure/spatial_repository.dart';
import 'package:famhub_app/core/services/supabase_service.dart';

/// ============================================================
/// SUPABASE SPATIAL REPOSITORY
/// ============================================================
///
/// All spatial data access flows through this repository.
/// Never query PostGIS directly from any module.
///
/// Table references (via Supabase RPC or direct queries):
///   spatial.spatial_assets
///   spatial.spatial_boundaries
///   spatial.spatial_capture_sessions
///   spatial.spatial_capture_points
///   spatial.spatial_overlaps
/// ============================================================
class SupabaseSpatialRepository implements SpatialRepository {
  final SupabaseService _supabase;

  SupabaseSpatialRepository(this._supabase);

  // ============================================================
  // SPATIAL ASSETS
  // ============================================================

  @override
  Future<List<SpatialAsset>> getAssets(String entityId) async {
    final response = await _supabase.client
        .from('spatial_assets')
        .select()
        .eq('entity_id', entityId)
        .order('name');

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => SpatialAsset.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SpatialAsset?> getAsset(String id) async {
    final response = await _supabase.client
        .from('spatial_assets')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return SpatialAsset.fromJson(response);
  }

  @override
  Future<List<SpatialAsset>> getChildAssets(String parentAssetId) async {
    final response = await _supabase.client
        .from('spatial_assets')
        .select()
        .eq('parent_asset_id', parentAssetId)
        .order('name');

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => SpatialAsset.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SpatialAsset>> getAssetsByType(
    String entityId,
    String assetType,
  ) async {
    final response = await _supabase.client
        .from('spatial_assets')
        .select()
        .eq('entity_id', entityId)
        .eq('asset_type', assetType)
        .order('name');

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => SpatialAsset.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // SPATIAL BOUNDARIES
  // ============================================================

  @override
  Future<List<SpatialBoundary>> getBoundaries(String assetId) async {
    final response = await _supabase.client
        .from('spatial_boundaries')
        .select()
        .eq('asset_id', assetId);

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) =>
            SpatialBoundary.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> uploadBoundary({
    required String assetId,
    required Map<String, dynamic> geometry,
    String accuracyLevel = 'gps',
  }) async {
    await _supabase.client.from('spatial_boundaries').insert({
      'asset_id': assetId,
      'geometry': geometry,
      'accuracy_level': accuracyLevel,
    });
  }

  // ============================================================
  // CAPTURE SESSIONS
  // ============================================================

  @override
  Future<List<CaptureSession>> getCaptureSessions(
    String assetId,
  ) async {
    final response = await _supabase.client
        .from('spatial_capture_sessions')
        .select()
        .eq('asset_id', assetId)
        .order('started_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) =>
            CaptureSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CaptureSession?> getActiveCaptureSession(
    String assetId,
  ) async {
    final response = await _supabase.client
        .from('spatial_capture_sessions')
        .select()
        .eq('asset_id', assetId)
        .eq('status', 'active')
        .maybeSingle();

    if (response == null) return null;
    return CaptureSession.fromJson(response);
  }

  @override
  Future<CaptureSession> startCapture({
    required String assetId,
    String mode = 'manual',
  }) async {
    final response = await _supabase.client
        .from('spatial_capture_sessions')
        .insert({
          'asset_id': assetId,
          'status': 'active',
          'mode': mode,
        })
        .select()
        .single();

    return CaptureSession.fromJson(response);
  }

  @override
  Future<void> finishCapture(String sessionId) async {
    await _supabase.client
        .from('spatial_capture_sessions')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().millisecondsSinceEpoch,
        })
        .eq('id', sessionId);
  }

  @override
  Future<void> cancelCapture(String sessionId) async {
    await _supabase.client
        .from('spatial_capture_sessions')
        .update({
          'status': 'cancelled',
          'completed_at': DateTime.now().millisecondsSinceEpoch,
        })
        .eq('id', sessionId);
  }

  // ============================================================
  // CAPTURE POINTS
  // ============================================================

  @override
  Future<List<CapturePoint>> getCapturePoints(String sessionId) async {
    final response = await _supabase.client
        .from('spatial_capture_points')
        .select()
        .eq('session_id', sessionId)
        .order('sequence_no');

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) =>
            CapturePoint.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CapturePoint> addCapturePoint({
    required String sessionId,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    int sequence = 0,
  }) async {
    final response = await _supabase.client
        .from('spatial_capture_points')
        .insert({
          'session_id': sessionId,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy_meters': accuracyMeters,
          'sequence_no': sequence,
        })
        .select()
        .single();

    return CapturePoint.fromJson(response);
  }

  // ============================================================
  // SPATIAL OVERLAPS
  // ============================================================

  @override
  Future<List<SpatialOverlap>> getOverlaps(String assetId) async {
    final response = await _supabase.client
        .from('spatial_overlaps')
        .select()
        .or('asset_a.eq.$assetId,asset_b.eq.$assetId');

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) =>
            SpatialOverlap.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SpatialOverlap>> detectOverlap(String assetId) async {
    // Use backend RPC to detect overlaps via PostGIS
    final response = await _supabase.client.rpc(
      'detect_spatial_overlaps',
      params: {'target_asset_id': assetId},
    );

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) =>
            SpatialOverlap.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
