/// ============================================================
/// FARM ONBOARDING PROVIDER
/// ============================================================
///
/// Manages the one-time post-creation experience:
///   - Tracks whether a farm was just created (show success card)
///   - Tracks onboarding checklist state
///   - Tracks whether guided setup card should be shown
///
/// The success message only appears immediately after creating a new farm.
/// The guided setup card appears when the farm has no crops and no livestock.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';

/// Onboarding state for a new farm
class FarmOnboardingState {
  /// Whether to show the one-time success card (true only immediately after farm creation)
  final bool showSuccessCard;

  /// Whether the setup guide card should be visible (no crops AND no livestock)
  final bool showSetupGuide;

  /// Whether the onboarding checklist should be visible
  final bool showChecklist;

  /// Checklist items
  final OnboardingChecklist checklist;

  const FarmOnboardingState({
    this.showSuccessCard = false,
    this.showSetupGuide = false,
    this.showChecklist = false,
    this.checklist = const OnboardingChecklist(),
  });

  FarmOnboardingState copyWith({
    bool? showSuccessCard,
    bool? showSetupGuide,
    bool? showChecklist,
    OnboardingChecklist? checklist,
  }) {
    return FarmOnboardingState(
      showSuccessCard: showSuccessCard ?? this.showSuccessCard,
      showSetupGuide: showSetupGuide ?? this.showSetupGuide,
      showChecklist: showChecklist ?? this.showChecklist,
      checklist: checklist ?? this.checklist,
    );
  }

  /// Factory for initial state with no farm selected
  factory FarmOnboardingState.initial() => const FarmOnboardingState();
}

/// Checklist for new farm onboarding
class OnboardingChecklist {
  final bool farmCreated;
  final bool mainFieldCreated;
  final bool firstCropOrLivestockAdded;
  final bool firstActivityRecorded;
  final bool firstReportViewed;

  const OnboardingChecklist({
    this.farmCreated = false,
    this.mainFieldCreated = false,
    this.firstCropOrLivestockAdded = false,
    this.firstActivityRecorded = false,
    this.firstReportViewed = false,
  });

  /// Number of completed items
  int get completedCount =>
      [farmCreated, mainFieldCreated, firstCropOrLivestockAdded, firstActivityRecorded, firstReportViewed]
          .where((e) => e)
          .length;

  /// Total number of items
  int get totalCount => 5;

  /// Whether all items are complete (hide checklist)
  bool get isComplete => completedCount >= totalCount;

  OnboardingChecklist copyWith({
    bool? farmCreated,
    bool? mainFieldCreated,
    bool? firstCropOrLivestockAdded,
    bool? firstActivityRecorded,
    bool? firstReportViewed,
  }) {
    return OnboardingChecklist(
      farmCreated: farmCreated ?? this.farmCreated,
      mainFieldCreated: mainFieldCreated ?? this.mainFieldCreated,
      firstCropOrLivestockAdded: firstCropOrLivestockAdded ?? this.firstCropOrLivestockAdded,
      firstActivityRecorded: firstActivityRecorded ?? this.firstActivityRecorded,
      firstReportViewed: firstReportViewed ?? this.firstReportViewed,
    );
  }
}

/// ============================================================
/// FARM ONBOARDING NOTIFIER
/// ============================================================
class FarmOnboardingNotifier extends Notifier<FarmOnboardingState> {
  @override
  FarmOnboardingState build() {
    // Listen for hierarchy changes and crop/livestock changes
    ref.listen<int>(
      hierarchyProvider.select((s) => s.version),
      (previous, next) {
        _evaluateState();
      },
    );

    // Also listen to crop and livestock state
    ref.listen<CropListState>(
      cropsProvider,
      (previous, next) {
        _updateChecklist();
      },
    );

    ref.listen<LivestockListState>(
      livestockProvider,
      (previous, next) {
        _updateChecklist();
      },
    );

    return FarmOnboardingState.initial();
  }

  /// Call this immediately after farm creation to show the success card
  void onFarmCreated() {
    state = state.copyWith(
      showSuccessCard: true,
      showSetupGuide: true,
      showChecklist: true,
      checklist: const OnboardingChecklist(
        farmCreated: true,
        mainFieldCreated: true,
      ),
    );
  }

  /// Dismiss the one-time success card
  void dismissSuccessCard() {
    state = state.copyWith(showSuccessCard: false);
  }

  /// Dismiss the setup guide card
  void dismissSetupGuide() {
    state = state.copyWith(showSetupGuide: false);
  }

  /// Called when first crop or livestock is added
  void onFirstCropOrLivestockAdded() {
    state = state.copyWith(
      showSetupGuide: false, // auto-hide guide once something is added
      showChecklist: state.showChecklist,
      checklist: state.checklist.copyWith(
        firstCropOrLivestockAdded: true,
      ),
    );
  }

  /// Called when first activity is recorded
  void onFirstActivityRecorded() {
    state = state.copyWith(
      checklist: state.checklist.copyWith(
        firstActivityRecorded: true,
      ),
    );
  }

  /// Called when first report is viewed
  void onFirstReportViewed() {
    state = state.copyWith(
      checklist: state.checklist.copyWith(
        firstReportViewed: true,
      ),
    );
  }

  /// Evaluate whether to show/hide the setup guide based on current state
  void _evaluateState() {
    _updateChecklist();
  }

  /// Update the checklist based on current crop/livestock state
  void _updateChecklist() {
    // Only update if we have a checklist active
    if (!state.showChecklist) return;

    bool hasCrops, hasLivestock;
    try {
      hasCrops = ref.read(cropsProvider).crops.isNotEmpty;
    } catch (_) {
      hasCrops = false;
    }
    try {
      hasLivestock = ref.read(livestockProvider).livestock.isNotEmpty;
    } catch (_) {
      hasLivestock = false;
    }

    final hasSomething = hasCrops || hasLivestock;

    if (hasSomething && !state.checklist.firstCropOrLivestockAdded) {
      state = state.copyWith(
        showSetupGuide: false,
        checklist: state.checklist.copyWith(
          firstCropOrLivestockAdded: true,
        ),
      );
    }

    // Auto-hide checklist when everything is complete
    if (state.checklist.isComplete) {
      state = state.copyWith(showChecklist: false);
    }
  }
}

/// ============================================================
/// PROVIDER
/// ============================================================
final farmOnboardingProvider =
    NotifierProvider<FarmOnboardingNotifier, FarmOnboardingState>(
  FarmOnboardingNotifier.new,
);