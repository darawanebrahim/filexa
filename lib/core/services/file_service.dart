import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/file_item.dart';

class FileService {
  Future<Directory> getFilexaDirectory() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return Directory(p.join(external.path, 'Filexa'));
      }
    }

    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'Filexa'));
  }

  Future<List<FileItem>> getDownloadedFiles() async {
    final directory = await getFilexaDirectory();
    if (!await directory.exists()) {
      return [];
    }

    final items = <FileItem>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;

      try {
        final stat = await entity.stat();
        items.add(
          FileItem(
            file: entity,
            name: p.basename(entity.path),
            path: entity.path,
            size: stat.size,
            modified: stat.modified,
          ),
        );
      } on FileSystemException {
        // Ignore a file that disappeared while the folder was being read.
      }
    }

    items.sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }

  Future<FileItem> renameFile(FileItem item, String newName) async {
    final safeName = _sanitizeFileName(newName);
    if (safeName.isEmpty) {
      throw const FileSystemException('The file name cannot be empty.');
    }

    final extension = p.extension(item.name);
    var finalName = safeName;
    if (p.extension(finalName).isEmpty && extension.isNotEmpty) {
      finalName = '$finalName$extension';
    }

    final newPath = p.join(p.dirname(item.path), finalName);
    if (newPath == item.path) return item;
    if (await File(newPath).exists()) {
      throw const FileSystemException('A file with this name already exists.');
    }

    final renamed = await item.file.rename(newPath);
    final stat = await renamed.stat();
    return FileItem(
      file: renamed,
      name: p.basename(renamed.path),
      path: renamed.path,
      size: stat.size,
      modified: stat.modified,
    );
  }

  Future<void> deleteFile(FileItem item) async {
    if (await item.file.exists()) {
      await item.file.delete();
    }
  }

  String _sanitizeFileName(String value) {
    return value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
