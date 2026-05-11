import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/deliverable_service.dart';
import '../../models/deliverable.dart';
import '../../config/environment.dart';

class ArtifactsOverviewScreen extends StatefulWidget {
  const ArtifactsOverviewScreen({super.key});

  @override
  State<ArtifactsOverviewScreen> createState() => _ArtifactsOverviewScreenState();
}

class _ArtifactsOverviewScreenState extends State<ArtifactsOverviewScreen> {
  final DeliverableService _deliverableService = DeliverableService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allArtifacts = []; // {artifact, deliverableTitle, deliverableId}

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final response = await _deliverableService.getDeliverables();
    if (response.isSuccess && response.data != null) {
      final List<Deliverable> deliverables = (response.data['deliverables'] as List)
          .cast<Deliverable>();
      
      final List<Map<String, dynamic>> artifacts = [];
      for (var d in deliverables) {
        for (var a in d.artifacts) {
          artifacts.add({
            'artifact': a,
            'deliverableTitle': d.title,
            'deliverableId': d.id,
          });
        }
      }

      // Sort by created date descending
      artifacts.sort((a, b) {
        final dateA = (a['artifact'] as DeliverableArtifact).createdAt;
        final dateB = (b['artifact'] as DeliverableArtifact).createdAt;
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _allArtifacts = artifacts;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getFileIcon(String fileType) {
    final type = fileType.toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('doc') || type.contains('word')) return Icons.description;
    if (type.contains('xls') || type.contains('sheet')) return Icons.table_chart;
    if (type.contains('ppt') || type.contains('presentation')) return Icons.slideshow;
    if (type.contains('img') || type.contains('png') || type.contains('jpg') || type.contains('jpeg')) return Icons.image;
    if (type.contains('zip') || type.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Future<void> _downloadArtifact(DeliverableArtifact artifact) async {
    try {
      String url = artifact.url;
      if (!url.startsWith('http')) {
         final baseUrl = Environment.apiBaseUrl.replaceAll('/api/v1', '');
         url = '$baseUrl/uploads/$url';
      }
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deliverable Artifacts')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allArtifacts.isEmpty
              ? const Center(child: Text('No artifacts found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allArtifacts.length,
                  itemBuilder: (context, index) {
                    final item = _allArtifacts[index];
                    final artifact = item['artifact'] as DeliverableArtifact;
                    final deliverableTitle = item['deliverableTitle'] as String;
                    
                    return Card(
                      child: ListTile(
                        leading: Icon(_getFileIcon(artifact.fileType)),
                        title: Text(artifact.originalName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Deliverable: $deliverableTitle'),
                            Text(
                              'Uploaded by ${artifact.uploaderName ?? artifact.uploadedBy} on ${DateFormat('MMM d, HH:mm').format(artifact.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _downloadArtifact(artifact),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
