import 'dart:io';

class FileItem {
  final File file;
  final String name;
  final String path;
  final int size;
  final DateTime modified;

  const FileItem({
    required this.file,
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
  });
}