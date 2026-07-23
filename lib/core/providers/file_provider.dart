import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../download_manager.dart';
import '../models/file_item.dart';
import '../services/file_service.dart';

final downloadManagerProvider = ChangeNotifierProvider<DownloadManager>((ref) {
  return DownloadManager.instance;
});

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

final filesProvider = FutureProvider<List<FileItem>>((ref) async {
  ref.watch(
    downloadManagerProvider.select((manager) => manager.fileRevision),
  );
  final service = ref.read(fileServiceProvider);
  return service.getDownloadedFiles();
});
