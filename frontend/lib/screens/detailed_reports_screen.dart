import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/flownet_theme.dart';

class DetailedReportsScreen extends ConsumerStatefulWidget {
  const DetailedReportsScreen({super.key});

  @override
  ConsumerState<DetailedReportsScreen> createState() => _DetailedReportsScreenState();
}

class _DetailedReportsScreenState extends ConsumerState<DetailedReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        title: const Text('Detailed Reports'),
        backgroundColor: FlownetColors.graphiteGray,
      ),
      body: const Center(
        child: Text(
          'Detailed Reports Screen',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}