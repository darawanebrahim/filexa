import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../download_manager.dart';
import '../models/file_item.dart';
import '../services/file_service.dart';

// The download manager is a process-wide singleton used by several legacy
// widgets. A ChangeNotifierProvider would take ownership of the returned
// notifier and dispose it with the ProviderScope, leaving AnimatedBuilder
// widgets attached to a disposed singleton. Keep it as a plain Provider and
// bridge notifications through a stream instead.
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager.instance;
});

final downloadManagerRevisionProvider = StreamProvider<int>((ref) {
  final manager = DownloadManager.instance;
  final controller = StreamController<int>();

  void listener() {
    if (!controller.isClosed) controller.add(manager.fileRevision);
  }

  manager.addListener(listener);
  ref.onDispose(() {
    manager.removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

final filesProvider = FutureProvider<List<FileItem>>((ref) async {
  ref.watch(downloadManagerRevisionProvider);
  final service = ref.read(fileServiceProvider);
  return service.getDownloadedFiles();
});
