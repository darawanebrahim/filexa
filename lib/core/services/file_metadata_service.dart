import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_service.dart';

class FileMetadata {
  const FileMetadata({this.favoritePaths = const <String>{}, this.tags = const <String, String>{}});

  final Set<String> favoritePaths;
  final Map<String, String> tags;

  FileMetadata copyWith({Set<String>? favoritePaths, Map<String, String>? tags}) {
    return FileMetadata(
      favoritePaths: favoritePaths ?? this.favoritePaths,
      tags: tags ?? this.tags,
    );
  }
}

class FileMetadataService {
  FileMetadataService(this._fileService);

  final FileService _fileService;

  Future<File> _metadataFile() async {
    final directory = await _fileService.getFilexaDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File(p.join(directory.path, '.filexa_metadata.json'));
  }

  Future<FileMetadata> load() async {
    try {
      final file = await _metadataFile();
      if (!await file.exists()) return const FileMetadata();
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final favorites = (decoded['favorites'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toSet();
      final tags = (decoded['tags'] as Map<String, dynamic>? ?? const <String, dynamic>{})
          .map((key, value) => MapEntry(key, value.toString()));
      return FileMetadata(favoritePaths: favorites, tags: tags);
    } catch (_) {
      return const FileMetadata();
    }
  }

  Future<void> save(FileMetadata metadata) async {
    final file = await _metadataFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'favorites': metadata.favoritePaths.toList()..sort(),
        'tags': metadata.tags,
      }),
      flush: true,
    );
  }
}
