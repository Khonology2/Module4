import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/deliverable.dart';
import '../models/sprint.dart';
import '../services/api_service.dart';
import '../services/api_client.dart';
import '../services/backend_api_service.dart';
import '../services/dashboard_service.dart';

class DashboardState {
  final List<Deliverable> deliverables;
  final List<Sprint> sprints;
  final DashboardStats? stats;
  final bool isLoading;
  final String? error;

  DashboardState({
    required this.deliverables,
    required this.sprints,
    this.stats,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    List<Deliverable>? deliverables,
    List<Sprint>? sprints,
    DashboardStats? stats,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      deliverables: deliverables ?? this.deliverables,
      sprints: sprints ?? this.sprints,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    return DashboardState(
      deliverables: [],
      sprints: [],
      stats: null,
      isLoading: false,
      error: null,
    );
  }

  Future<void> loadDashboardData() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // Fetch dashboard data concurrently
      final deliverablesFuture = ApiService.getDeliverables();
      final sprintsFuture = ApiService.getSprints();
      final analyticsFuture = BackendApiService().getDashboardData();
      
      final results = await Future.wait([
        deliverablesFuture,
        sprintsFuture,
        analyticsFuture,
      ]);
      
      final List<Deliverable> deliverables = (results[0] as List).map((json) => Deliverable.fromJson(json)).toList();
      final List<Sprint> sprints = (results[1] as List).map((json) => Sprint.fromJson(json)).toList();
      DashboardStats? stats;
      final analyticsResponse = results[2];
      if (analyticsResponse is ApiResponse && analyticsResponse.isSuccess && analyticsResponse.data != null) {
        final raw = analyticsResponse.data;
        if (raw is Map<String, dynamic>) {
          stats = DashboardStats.fromJson(raw);
        } else if (raw is Map) {
          stats = DashboardStats.fromJson(Map<String, dynamic>.from(raw));
        }
      }
      
      state = state.copyWith(
        deliverables: deliverables,
        sprints: sprints,
        stats: stats,
        isLoading: false,
      );
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load dashboard data: $e',
      );
      debugPrint('Error loading dashboard data: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final dashboardNotifierProvider = NotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});
