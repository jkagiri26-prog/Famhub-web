import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feature_flags/application/services/feature_access_service.dart';

/// A reusable widget to gate access to features based on feature flags.
///
/// It hides or shows content based on the user's access rights determined by
/// the FeatureAccessService. If access is denied, it can display a placeholder
/// widget or a locked state.
class FeatureGate extends StatelessWidget {
  final String featureKey;
  final Widget child; // The widget to display if access is granted
  final Widget? lockedWidget; // Widget to display if access is denied (e.g., upgrade prompt)
  final Widget? maintenanceWidget; // Widget to display if feature is under maintenance
  final Widget? adminOnlyWidget; // Widget to display if feature is admin-only and user is not admin

  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.lockedWidget,
    this.maintenanceWidget,
    this.adminOnlyWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Note: In a real app, you'd use a Riverpod ConsumerWidget to access providers.
    // For simplicity, we're calling the static method here, assuming it has access to necessary context
    // or that the necessary context (isPremiumUser, isAdmin) is passed in or globally available.
    
    // Placeholder values for premium and admin status. These should be resolved from user context.
    const bool isPremiumUser = false; // Replace with actual user premium status
    const bool isAdmin = false; // Replace with actual admin status

    // Check if the feature is accessible
    if (FeatureAccessService.canAccessFeature(
      featureKey: featureKey,
      isPremiumUser: isPremiumUser,
      isAdmin: isAdmin,
    )) {
      // Access granted, display the child widget
      return child;
    } else {
      // Access denied, determine the reason and display appropriate widget
      // Re-evaluate the conditions to determine which specific denial widget to show.
      // This logic might be more sophisticated in a real app, possibly involving more detailed checks in FeatureAccessService.
      
      // Check for maintenance mode first as it's a temporary state
      // We need to re-fetch the flag to check maintenanceMode specifically
      // This is a bit redundant and could be optimized by returning more detailed states from canAccessFeature
      final Map<String, FeatureFlag> dummyFeatureFlags = {
        'ai_advisory': const FeatureFlag(featureKey: 'ai_advisory', isEnabled: true, premiumOnly: true, adminOnly: false, maintenanceMode: false),
        'carbon_tracking': const FeatureFlag(featureKey: 'carbon_tracking', isEnabled: true, premiumOnly: false, adminOnly: false, maintenanceMode: false),
        'premium_analytics': const FeatureFlag(featureKey: 'premium_analytics', isEnabled: true, premiumOnly: true, adminOnly: false, maintenanceMode: false),
        'export_tools': const FeatureFlag(featureKey: 'export_tools', isEnabled: true, premiumOnly: false, adminOnly: true, maintenanceMode: false),
        'advanced_reporting': const FeatureFlag(featureKey: 'advanced_reporting', isEnabled: true, premiumOnly: true, adminOnly: false, maintenanceMode: false),
        'carbon_credit_dashboard': const FeatureFlag(featureKey: 'carbon_credit_dashboard', isEnabled: true, premiumOnly: false, adminOnly: false, maintenanceMode: false),
      };
      final flag = dummyFeatureFlags[featureKey];

      if (flag?.maintenanceMode ?? false) {
        return maintenanceWidget ?? const SizedBox.shrink(); // Show maintenance widget or nothing
      }
      if (flag?.adminOnly ?? false) {
         return adminOnlyWidget ?? const SizedBox.shrink(); // Show admin-only widget or nothing
      }
      if (flag?.premiumOnly ?? false) {
        return lockedWidget ?? const SizedBox.shrink(); // Show locked widget (e.g., upgrade prompt) or nothing
      }
      
      // Default to locked widget if no specific reason is identified or if lockedWidget is provided
      return lockedWidget ?? const SizedBox.shrink();
    }
  }
}
