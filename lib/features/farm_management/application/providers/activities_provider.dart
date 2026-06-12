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
      errorMessage: errorMessage,
    );
  }
}

/// Activities notifier
class ActivitiesNotifier extends StateNotifier<ActivityListState> {
  final FarmRepository _repository;
  final String? _farmId;

  ActivitiesNotifier(this._repository, this._farmId)
      : super(ActivityListState.initial());

  Future<void> loadActivities() async {
    if (_farmId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final activities = await _repository.getActivities(farmId: _farmId!);
      state = state.copyWith(activities: activities, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

/// Provider for activity list
final activitiesProvider = StateNotifierProvider.family<ActivitiesNotifier, ActivityListState, String?>(
  (ref, farmId) {
    final repository = ref.read(farmRepositoryProvider);
    return ActivitiesNotifier(repository, farmId);
  },
);
