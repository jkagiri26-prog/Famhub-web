/// ============================================================
/// BUSINESS PROFILE SETUP — APPLICATION CONTROLLER
/// ============================================================
///
/// Drives the Trader first-use "Create your business" submission.
///
/// Architecture:
///   Presentation (CreateBusinessPage)
///     → Application (this controller)
///     → Domain (BusinessHubRepository)
///     → Infrastructure (BusinessHubRemoteDataSource)
///     → Supabase RPC (commerce.create_business_profile)
///
/// The controller never fabricates context. After a successful create it
/// only reports success; the caller refreshes the authoritative context
/// through the existing ContextController and then the Trader gate
/// re-resolves from `businessProfileId`.
/// ============================================================
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/business_hub/domain/enums/business_profile_category.dart';
import 'business_hub_repository_provider.dart';

/// Submission state for the Create Business screen.
class BusinessProfileSetupState {
  final bool isSubmitting;
  final String? errorMessage;

  /// `commerce.business_profiles.id` resolved after a successful create.
  /// Used by the caller to establish the canonical active context.
  final String? createdBusinessProfileId;

  const BusinessProfileSetupState({
    this.isSubmitting = false,
    this.errorMessage,
    this.createdBusinessProfileId,
  });
}

class BusinessProfileSetupController
    extends Notifier<BusinessProfileSetupState> {
  @override
  BusinessProfileSetupState build() => const BusinessProfileSetupState();

  /// Create (or resolve the existing) business profile for the ACTIVE
  /// entity. Returns true when the backend completed successfully —
  /// including the idempotent `already_exists` case.
  Future<bool> createBusiness({
    required String entityId,
    required String supplierName,
    required BusinessProfileCategory category,
    String? otherDescription,
  }) async {
    state = const BusinessProfileSetupState(isSubmitting: true);

    final metadata = <String, dynamic>{
      'business_category': category.machineValue,
    };
    final description = otherDescription?.trim();
    if (category == BusinessProfileCategory.other &&
        description != null &&
        description.isNotEmpty) {
      metadata['business_description'] = description;
    }

    try {
      final repo = ref.read(businessHubRepositoryProvider);
      final result = await repo.createBusinessProfile(
        entityId: entityId,
        supplierName: supplierName.trim(),
        entityType: category.dbEntityType,
        metadata: metadata,
      );

      // Resolve the profile id so the caller can link it to the canonical
      // active context. The RPC normally returns it; fall back to a direct
      // read when the RPC is void/returns only flags.
      var profileId = result.businessProfileId;
      if (profileId == null || profileId.isEmpty) {
        try {
          final profile = await repo.fetchBusinessProfile(entityId);
          profileId = profile?.id;
        } catch (_) {
          profileId = null;
        }
      }

      state = BusinessProfileSetupState(createdBusinessProfileId: profileId);
      return true;
    } catch (e) {
      debugPrint('[BusinessProfileSetup] create failed: $e');
      state = BusinessProfileSetupState(errorMessage: _friendlyError(e));
      return false;
    }
  }

  /// Clear a previous error (e.g. when the user edits the form).
  void clearError() {
    if (state.errorMessage == null) return;
    state = const BusinessProfileSetupState();
  }

  /// Map backend/network failures to a friendly, non-technical message.
  String _friendlyError(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
      if (code == '42501' ||
          message.contains('permission') ||
          message.contains('not authorized') ||
          message.contains('forbidden') ||
          message.contains('insufficient')) {
        return 'You do not have permission to create a business under '
            'this entity. Please contact the business owner or an '
            'administrator.';
      }
      if (message.contains('authentication') ||
          message.contains('not authenticated') ||
          message.contains('jwt')) {
        return 'Your session has expired. Please sign in again.';
      }
    }
    return 'Could not create your business right now. Please check your '
        'connection and try again.';
  }
}

final businessProfileSetupControllerProvider =
    NotifierProvider<BusinessProfileSetupController, BusinessProfileSetupState>(
      BusinessProfileSetupController.new,
    );
