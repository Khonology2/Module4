class RepositoryFile {
  final String id;
  final String name;
  final String fileType;
  final DateTime uploadDate;
  final String uploadedBy;
  final String size;
  final String description;
  final String uploader;
  final double sizeInMB; // in MB
  final String? filePath;
  final String? tags;
  final String? uploaderName;

  const RepositoryFile({
    required this.id,
    required this.name,
    required this.fileType,
    required this.uploadDate,
    required this.uploadedBy,
    required this.size,
    required this.description,
    required this.uploader,
    required this.sizeInMB,
    this.filePath,
    this.tags,
    this.uploaderName,
  });

  RepositoryFile copyWith({
    String? id,
    String? name,
    String? fileType,
    DateTime? uploadDate,
    String? uploadedBy,
    String? size,
    String? description,
    String? uploader,
    double? sizeInMB,
    String? filePath,
    String? tags,
    String? uploaderName,
  }) {
    return RepositoryFile(
      id: id ?? this.id,
      name: name ?? this.name,
      fileType: fileType ?? this.fileType,
      uploadDate: uploadDate ?? this.uploadDate,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      size: size ?? this.size,
      description: description ?? this.description,
      uploader: uploader ?? this.uploader,
      sizeInMB: sizeInMB ?? this.sizeInMB,
      filePath: filePath ?? this.filePath,
      tags: tags ?? this.tags,
      uploaderName: uploaderName ?? this.uploaderName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fileType': fileType,
      'uploadDate': uploadDate.toIso8601String(),
      'uploadedBy': uploadedBy,
      'size': size,
      'description': description,
      'uploader': uploader,
      'sizeInMB': sizeInMB,
      'filePath': filePath,
      'tags': tags,
      'uploaderName': uploaderName,
    };
  }

  factory RepositoryFile.fromJson(Map<String, dynamic> json) {
    return RepositoryFile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['file_name'] ?? '',
      fileType: json['file_type'] ?? json['fileType'] ?? '',
      uploadDate: DateTime.parse(json['uploaded_at'] ?? json['uploadDate']),
      uploadedBy: json['uploaded_by']?.toString() ?? json['uploadedBy']?.toString() ?? '',
      size: _parseSize(json['file_size'] ?? json['size']),
      description: json['description'] ?? '',
      uploader: json['uploader'] ?? '',
      sizeInMB: _parseDouble(json['size_in_mb']) ?? _parseDouble(json['sizeInMB']) ?? 0.0,
      filePath: json['file_path'],
      tags: json['tags'],
      uploaderName: json['uploader_name'],
    );
  }

  static String _parseSize(dynamic value) {
    if (value == null) return '0';
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is double) return value.toStringAsFixed(0);
    return value.toString();
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
