// Stub file for path_provider on web platform
// This file is used when compiling for web where path_provider is not available

class Directory {
  final String path;
  Directory(this.path);
}

Future<Directory> getTemporaryDirectory() {
  throw UnsupportedError('getTemporaryDirectory is not available on web platform');
}

