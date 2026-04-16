import 'package:flutter/material.dart';
import '../models/deliverable.dart';
import '../services/backend_api_service.dart';
import 'deliverable_detail_screen.dart';

class DeliverableDetailByIdScreen extends StatefulWidget {
  final String deliverableId;

  const DeliverableDetailByIdScreen({super.key, required this.deliverableId});

  @override
  State<DeliverableDetailByIdScreen> createState() => _DeliverableDetailByIdScreenState();
}

class _DeliverableDetailByIdScreenState extends State<DeliverableDetailByIdScreen> {
  bool _loading = true;
  String? _error;
  Deliverable? _deliverable;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await BackendApiService().getDeliverable(widget.deliverableId);
      if (!mounted) return;
      if (!resp.isSuccess || resp.data == null) {
        setState(() {
          _error = resp.error ?? 'Failed to load deliverable.';
          _loading = false;
        });
        return;
      }
      final raw = resp.data;
      final dJson = raw is Map
          ? (raw['data'] ?? raw['deliverable'] ?? raw)
          : raw;
      if (dJson is! Map) {
        setState(() {
          _error = 'Unexpected deliverable response format.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _deliverable = Deliverable.fromJson(Map<String, dynamic>.from(dJson));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to open deliverable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(_error ?? 'Unknown error'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final d = _deliverable;
    if (d == null) {
      return const Center(child: Text('Deliverable not found.'));
    }
    return DeliverableDetailScreen(deliverable: d);
  }
}

