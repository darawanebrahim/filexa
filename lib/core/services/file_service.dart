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

  Future<FileItem> copyFile(FileItem item, String folderName) async {
    final root = await getFilexaDirectory();
    final safeFolder = _sanitizeFileName(folderName);
    if (safeFolder.isEmpty) {
      throw const FileSystemException('The destination folder cannot be empty.');
    }
    final destination = Directory(p.join(root.path, safeFolder));
    if (!await destination.exists()) await destination.create(recursive: true);
    final targetPath = await _availablePath(destination.path, item.name);
    final copied = await item.file.copy(targetPath);
    final stat = await copied.stat();
    return FileItem(file: copied, name: p.basename(copied.path), path: copied.path, size: stat.size, modified: stat.modified);
  }

  Future<FileItem> moveFile(FileItem item, String folderName) async {
    final root = await getFilexaDirectory();
    final safeFolder = _sanitizeFileName(folderName);
    if (safeFolder.isEmpty) {
      throw const FileSystemException('The destination folder cannot be empty.');
    }
    final destination = Directory(p.join(root.path, safeFolder));
    if (!await destination.exists()) await destination.create(recursive: true);
    final targetPath = await _availablePath(destination.path, item.name);
    File moved;
    try {
      moved = await item.file.rename(targetPath);
    } on FileSystemException {
      moved = await item.file.copy(targetPath);
      await item.file.delete();
    }
    final stat = await moved.stat();
    return FileItem(file: moved, name: p.basename(moved.path), path: moved.path, size: stat.size, modified: stat.modified);
  }

  Future<List<String>> getManagedFolders() async {
    final root = await getFilexaDirectory();
    if (!await root.exists()) return const <String>[];
    final folders = <String>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory) folders.add(p.basename(entity.path));
    }
    folders.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return folders;
  }

  Future<String> _availablePath(String directory, String fileName) async {
    var candidate = p.join(directory, fileName);
    if (!await File(candidate).exists()) return candidate;
    final base = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var index = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(directory, '$base ($index)$extension');
      index++;
    }
    return candidate;
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
