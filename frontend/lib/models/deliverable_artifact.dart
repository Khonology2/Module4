class DeliverableArtifact {
  final String id;
  final String deliverableId;
  final String filename;
  final String originalName;
  final String fileType;
  final int fileSize;
  final String url;
  final String uploadedBy;
  final String? uploaderName;
  final DateTime createdAt;

  const DeliverableArtifact({
    required this.id,
    required this.deliverableId,
    required this.filename,
    required this.originalName,
    required this.fileType,
    required this.fileSize,
    required this.url,
    required this.uploadedBy,
    this.uploaderName,
    required this.createdAt,
  });

  factory DeliverableArtifact.fromJson(Map<String, dynamic> json) {
    return DeliverableArtifact(
      id: json['id']?.toString() ?? '',
      deliverableId: json['deliverable_id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? '',
      fileType: json['file_type']?.toString() ?? '',
      fileSize: json['file_size'] is int ? json['file_size'] : int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
      url: json['url']?.toString() ?? '',
      uploadedBy: json['uploaded_by']?.toString() ?? '',
      uploaderName: json['uploader_name']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliverable_id': deliverableId,
      'filename': filename,
      'original_name': originalName,
      'file_type': fileType,
      'file_size': fileSize,
      'url': url,
      'uploaded_by': uploadedBy,
      'uploader_name': uploaderName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
