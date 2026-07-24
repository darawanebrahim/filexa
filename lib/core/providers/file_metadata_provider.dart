import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/file_metadata_service.dart';
import 'file_provider.dart';

final fileMetadataServiceProvider = Provider<FileMetadataService>((ref) {
  return FileMetadataService(ref.read(fileServiceProvider));
});

final fileMetadataProvider = AsyncNotifierProvider<FileMetadataNotifier, FileMetadata>(
  FileMetadataNotifier.new,
);

class FileMetadataNotifier extends AsyncNotifier<FileMetadata> {
  FileMetadataService get _service => ref.read(fileMetadataServiceProvider);

  @override
  Future<FileMetadata> build() => _service.load();

  Future<void> toggleFavorite(String path) async {
    final current = state.valueOrNull ?? await _service.load();
    final favorites = <String>{...current.favoritePaths};
    if (!favorites.add(path)) favorites.remove(path);
    final next = current.copyWith(favoritePaths: favorites);
    state = AsyncData(next);
    await _service.save(next);
  }

  Future<void> setTag(String path, String? tag) async {
    final current = state.valueOrNull ?? await _service.load();
    final tags = <String, String>{...current.tags};
    final value = tag?.trim() ?? '';
    if (value.isEmpty) {
      tags.remove(path);
    } else {
      tags[path] = value;
    }
    final next = current.copyWith(tags: tags);
    state = AsyncData(next);
    await _service.save(next);
  }

  Future<void> removePath(String path) async {
    final current = state.valueOrNull ?? await _service.load();
    final favorites = <String>{...current.favoritePaths}..remove(path);
    final tags = <String, String>{...current.tags}..remove(path);
    final next = current.copyWith(favoritePaths: favorites, tags: tags);
    state = AsyncData(next);
    await _service.save(next);
  }

  Future<void> movePath(String oldPath, String newPath) async {
    final current = state.valueOrNull ?? await _service.load();
    final favorites = <String>{...current.favoritePaths};
    if (favorites.remove(oldPath)) favorites.add(newPath);
    final tags = <String, String>{...current.tags};
    final tag = tags.remove(oldPath);
    if (tag != null) tags[newPath] = tag;
    final next = current.copyWith(favoritePaths: favorites, tags: tags);
    state = AsyncData(next);
    await _service.save(next);
  }
}
