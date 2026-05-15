import '../../domain/models/activity_model.dart';
import '../../domain/models/farm_dashboard_summary.dart';

class FarmDashboardState {
  final FarmDashboardSummary summary;
  final List<ActivityModel> todayActivities;
  final String? errorMessage;

  const FarmDashboardState({
    required this.summary,
    required this.todayActivities,
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
      errorMessage: null,
    );
  }

  FarmDashboardState copyWith({
    FarmDashboardSummary? summary,
    List<ActivityModel>? todayActivities,
    String? errorMessage,
  }) {
    return FarmDashboardState(
      summary: summary ?? this.summary,
      todayActivities: todayActivities ?? this.todayActivities,
      errorMessage: errorMessage,
    );
  }
}