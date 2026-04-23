import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/deliverable.dart';
import '../models/sprint.dart';
import '../services/api_service.dart';

class DashboardState {
  final List<Deliverable> deliverables;
  final List<Sprint> sprints;
  final bool isLoading;
  final String? error;

  DashboardState({
    required this.deliverables,
    required this.sprints,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    List<Deliverable>? deliverables,
    List<Sprint>? sprints,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      deliverables: deliverables ?? this.deliverables,
      sprints: sprints ?? this.sprints,
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
      
      final results = await Future.wait([
        deliverablesFuture,
        sprintsFuture,
      ]);
      
      final List<Deliverable> deliverables = (results[0] as List).map((json) => Deliverable.fromJson(json)).toList();
      final List<Sprint> sprints = (results[1] as List).map((json) => Sprint.fromJson(json)).toList();
      
      state = state.copyWith(
        deliverables: deliverables,
        sprints: sprints,
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
