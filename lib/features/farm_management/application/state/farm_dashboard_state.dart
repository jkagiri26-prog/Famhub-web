import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';

class FarmDashboardState {
  final FarmDashboardSummary summary;
  final List<ActivityModel> todayActivities;
  final bool isLoading;
  final String? farmId;
  final String? errorMessage;

  const FarmDashboardState({
    required this.summary,
    required this.todayActivities,
    required this.isLoading,
    this.farmId,
    this.errorMessage,
  });

  factory FarmDashboardState.initial() {
    return const FarmDashboardState(
      summary: FarmDashboardSummary(
        totalProduction: 0,
        totalSales: 0,
        totalExpenses: 0,
        totalYield: 0,
        stockValue: 0,
      ),
      todayActivities: [],
      isLoading: true,
      farmId: null,
      errorMessage: null,
    );
  }

  FarmDashboardState copyWith({
    FarmDashboardSummary? summary,
    List<ActivityModel>? todayActivities,
    bool? isLoading,
    String? farmId,
    String? errorMessage,
  }) {
    return FarmDashboardState(
      summary: summary ?? this.summary,
      todayActivities: todayActivities ?? this.todayActivities,
      isLoading: isLoading ?? this.isLoading,
      farmId: farmId ?? this.farmId,
      errorMessage: errorMessage,
    );
  }
}