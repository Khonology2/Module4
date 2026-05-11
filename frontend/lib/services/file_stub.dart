// Stub file for File on web platform
// This file is used when compiling for web where dart:io File is not available

class File {
  final String path;
  File(this.path);
  
  Future<File> writeAsBytes(List<int> bytes) {
    throw UnsupportedError('File.writeAsBytes is not available on web platform');
  }
}

