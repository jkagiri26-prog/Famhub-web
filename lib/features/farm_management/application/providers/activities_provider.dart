/// ============================================================
/// ACTIVITIES PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// ✅ PATTERN: repository → provider → state → widgets
///
/// Provides farm activity timeline and management operations.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';

/// Activity list state
class ActivityListState {
  final List<ActivityModel> activities;
  final bool isLoading;
  final String? errorMessage;

  const ActivityListState({
    required this.activities,
    required this.isLoading,
    this.errorMessage,
  });

  factory ActivityListState.initial() => const ActivityListState(
        activities: [],
        isLoading: true,
      );

  ActivityListState copyWith({
    List<ActivityModel>? activities,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ActivityListState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ============================================================
/// ACTIVITIES NOTIFIER (RIVERPOD 3 - NOTIFIER API)
/// ============================================================
class ActivitiesNotifier extends Notifier<ActivityListState> {
  late final String? _farmId;

  FarmRepository get _repository =>
      ref.read(farmRepositoryProvider);

  @override
  ActivityListState build() {
    // The farmId is set via `currentFarmIdProvider` or similar
    return ActivityListState.initial();
  }

  void setFarmId(String? farmId) {
    _farmId = farmId;
    // Reload when farm changes
    loadActivities();
  }

  Future<void> loadActivities() async {
    if (_farmId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final activities =
          await _repository.getActivities(farmId: _farmId);

      state = state.copyWith(
        activities: activities,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

/// ============================================================
/// PROVIDER (NOTIFIER)
/// ============================================================
final activitiesProvider =
    NotifierProvider<ActivitiesNotifier, ActivityListState>(
  ActivitiesNotifier.new,
);

