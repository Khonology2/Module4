import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:khono/models/deliverable.dart';
import 'package:khono/services/backend_api_service.dart';
import 'package:khono/widgets/deliverable_card.dart';
import 'package:khono/services/auth_service.dart';

class DeliverablesListScreen extends StatefulWidget {
  const DeliverablesListScreen({super.key});

  @override
  State<DeliverablesListScreen> createState() => _DeliverablesListScreenState();
}

class _DeliverablesListScreenState extends State<DeliverablesListScreen> {
  final _backendService = BackendApiService();
  List<Deliverable> _deliverables = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeliverables();
  }

  Future<void> _loadDeliverables() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch with a high limit to get all deliverables for now
      final response = await _backendService.getDeliverables(limit: 100);
      
      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data;
        final List<dynamic> items = (raw is Map)
            ? (raw['data'] ?? raw['deliverables'] ?? raw['items'] ?? [])
            : (raw is List ? raw : []);
            
        final List<Deliverable> parsedDeliverables = [];
        
        for (final item in items) {
          try {
            if (item is Map<String, dynamic>) {
              // Ensure required fields exist or have defaults before parsing
              // This is to handle potential inconsistencies seen in dashboard code
              final safeMap = Map<String, dynamic>.from(item);
              
              // Map varying title keys to 'title'
              if (!safeMap.containsKey('title')) {
                safeMap['title'] = safeMap['name'] ?? safeMap['deliverableName'] ?? 'Untitled Deliverable';
              }
              
              // Handle status if it's not matching enum string exactly
              // Deliverable.fromJson expects specific enum strings
              
              parsedDeliverables.add(Deliverable.fromJson(safeMap));
            }
          } catch (e) {
            debugPrint('Error parsing deliverable: $e');
            // Continue to next item
          }
        }
        
        setState(() {
          _deliverables = parsedDeliverables;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to load deliverables';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = AuthService().canCreateDeliverable();
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Deliverables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliverables,
          ),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/deliverable-setup'),
              tooltip: 'Create Deliverable',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDeliverables,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _deliverables.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No deliverables found'),
                          const SizedBox(height: 16),
                          if (canCreate)
                            ElevatedButton.icon(
                              onPressed: () => context.go('/deliverable-setup'),
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Deliverable'),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDeliverables,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _deliverables.length,
                        itemBuilder: (context, index) {
                          final deliverable = _deliverables[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DeliverableCard(
                              deliverable: deliverable,
                              onTap: () {
                                // Navigate to deliverable detail for editing/viewing
                                context.push('/deliverable-detail', extra: deliverable);
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
