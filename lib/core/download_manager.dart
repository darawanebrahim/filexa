import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'download_task.dart';

class DownloadManager extends ChangeNotifier {
  DownloadManager._();

  static final DownloadManager instance = DownloadManager._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  final List<DownloadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _pauseRequested = {};
  int _fileRevision = 0;
  static const int maxConcurrentDownloads = 2;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  int get fileRevision => _fileRevision;

  List<DownloadTask> get activeTasks =>
      _tasks.where((task) => task.isActive).toList(growable: false);

  List<DownloadTask> get completedTasks => _tasks
      .where((task) => task.status == DownloadStatus.completed)
      .toList(growable: false);

  List<DownloadTask> get failedTasks => _tasks
      .where((task) =>
          task.status == DownloadStatus.failed ||
          task.status == DownloadStatus.canceled)
      .toList(growable: false);

  Future<DownloadTask> startDownload({
    required String url,
    required String fileName,
    required String folder,
    Map<String, String> headers = const <String, String>{},
    DownloadPriority priority = DownloadPriority.normal,
  }) async {
    final task = DownloadTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url,
      fileName: _sanitizeFileName(fileName),
      folder: folder,
      createdAt: DateTime.now(),
      headers: Map<String, String>.unmodifiable(headers),
      priority: priority,
    );

    _tasks.insert(0, task);
    notifyListeners();
    _pumpQueue();
    return task;
  }

  void _pumpQueue() {
    final running = _tasks
        .where((task) => task.status == DownloadStatus.downloading)
        .length;
    final available = maxConcurrentDownloads - running;
    if (available <= 0) return;

    final waiting = _tasks
        .where((task) => task.status == DownloadStatus.queued)
        .toList(growable: false)
      ..sort((a, b) {
        final priority = _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
        if (priority != 0) return priority;
        return a.createdAt.compareTo(b.createdAt);
      });
    for (final task in waiting.take(available)) {
      unawaited(_download(task));
    }
  }


  bool hasDuplicateName(String fileName) {
    final normalized = _sanitizeFileName(fileName).toLowerCase();
    return _tasks.any((task) => task.fileName.toLowerCase() == normalized &&
        task.status != DownloadStatus.canceled);
  }

  void setPriority(String taskId, DownloadPriority priority) {
    final task = _findTask(taskId);
    if (task == null || task.status == DownloadStatus.completed) return;
    task.priority = priority;
    notifyListeners();
    _pumpQueue();
  }

  int _priorityRank(DownloadPriority priority) => switch (priority) {
        DownloadPriority.high => 0,
        DownloadPriority.normal => 1,
        DownloadPriority.low => 2,
      };

  int get queuedCount =>
      _tasks.where((task) => task.status == DownloadStatus.queued).length;

  int get pausedCount =>
      _tasks.where((task) => task.status == DownloadStatus.paused).length;

  Future<void> _download(DownloadTask task) async {
    if (_cancelTokens.containsKey(task.id)) return;

    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;
    _pauseRequested.remove(task.id);

    final stopwatch = Stopwatch()..start();
    var lastReceived = task.receivedBytes;
    var lastTick = Duration.zero;

    try {
      task.status = DownloadStatus.downloading;
      task.errorMessage = null;
      task.speedBytesPerSecond = 0;
      notifyListeners();

      if (task.savedPath == null) {
        task.fileName = await _resolveRemoteFileName(
          task.url,
          task.fileName,
          cancelToken,
          task.headers,
        );
        final targetDirectory = await _resolveTargetDirectory();
        await targetDirectory.create(recursive: true);
        task.savedPath = await _uniquePath(targetDirectory.path, task.fileName);
        task.fileName = p.basename(task.savedPath!);
      }

      final finalFile = File(task.savedPath!);
      final partFile = File('${task.savedPath!}.part');
      final existingBytes = await partFile.exists() ? await partFile.length() : 0;
      task.receivedBytes = existingBytes;

      final headers = <String, dynamic>{
        HttpHeaders.acceptEncodingHeader: 'identity',
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
        ...task.headers,
      };
      if (existingBytes > 0) {
        headers[HttpHeaders.rangeHeader] = 'bytes=$existingBytes-';
      }

      final response = await _dio.get<ResponseBody>(
        task.url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
      );

      final resumes = existingBytes > 0 && response.statusCode == 206;
      final startBytes = resumes ? existingBytes : 0;
      if (!resumes && existingBytes > 0) {
        await partFile.writeAsBytes(const <int>[], flush: true);
        task.receivedBytes = 0;
      }

      final contentLength = int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '',
          ) ??
          0;
      task.totalBytes = contentLength > 0 ? startBytes + contentLength : 0;
      final sink = partFile.openWrite(
        mode: resumes ? FileMode.append : FileMode.write,
      );

      try {
        await for (final Uint8List chunk in response.data!.stream) {
          sink.add(chunk);
          task.receivedBytes += chunk.length;
          if (task.totalBytes > 0) {
            task.progress = task.receivedBytes / task.totalBytes;
          }

          final elapsed = stopwatch.elapsed;
          final deltaTime = elapsed - lastTick;
          if (deltaTime.inMilliseconds >= 400) {
            final deltaBytes = task.receivedBytes - lastReceived;
            task.speedBytesPerSecond =
                deltaBytes / (deltaTime.inMilliseconds / 1000);
            lastReceived = task.receivedBytes;
            lastTick = elapsed;
            notifyListeners();
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (await finalFile.exists()) await finalFile.delete();
      await partFile.rename(finalFile.path);
      task.receivedBytes = await finalFile.length();
      if (task.totalBytes <= 0) task.totalBytes = task.receivedBytes;
      task.progress = 1;
      task.speedBytesPerSecond = 0;
      task.status = DownloadStatus.completed;
      _fileRevision++;
      notifyListeners();
    } on DioException catch (error) {
      task.speedBytesPerSecond = 0;
      if (CancelToken.isCancel(error)) {
        if (_pauseRequested.remove(task.id)) {
          task.status = DownloadStatus.paused;
          task.errorMessage = null;
        } else {
          task.status = DownloadStatus.canceled;
          task.errorMessage = 'Download canceled.';
        }
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = _friendlyDioMessage(error);
      }
      notifyListeners();
    } on FileSystemException catch (error) {
      task.status = DownloadStatus.failed;
      task.speedBytesPerSecond = 0;
      task.errorMessage = error.message;
      notifyListeners();
    } catch (error) {
      task.status = DownloadStatus.failed;
      task.speedBytesPerSecond = 0;
      task.errorMessage = 'Unexpected error: $error';
      notifyListeners();
    } finally {
      stopwatch.stop();
      _cancelTokens.remove(task.id);
      _pumpQueue();
    }
  }

  void pauseDownload(String taskId) {
    final task = _findTask(taskId);
    final token = _cancelTokens[taskId];
    if (task == null || !task.canPause || token == null || token.isCancelled) {
      return;
    }
    _pauseRequested.add(taskId);
    token.cancel('Paused by user');
  }

  void resumeDownload(String taskId) {
    final task = _findTask(taskId);
    if (task == null || !task.canResume) return;
    task.status = DownloadStatus.queued;
    notifyListeners();
    _pumpQueue();
  }

  void pauseAll() {
    for (final task in List<DownloadTask>.of(_tasks)) {
      if (task.canPause) pauseDownload(task.id);
    }
  }

  void resumeAll() {
    for (final task in List<DownloadTask>.of(_tasks)) {
      if (task.canResume) resumeDownload(task.id);
    }
  }

  void cancelDownload(String taskId) {
    _pauseRequested.remove(taskId);
    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      token.cancel('Canceled by user');
      return;
    }
    final task = _findTask(taskId);
    if (task != null && task.status == DownloadStatus.paused) {
      task.status = DownloadStatus.canceled;
      notifyListeners();
    }
  }

  Future<void> retryDownload(String taskId) async {
    final task = _findTask(taskId);
    if (task == null || task.isActive) return;
    final partPath = task.savedPath == null ? null : '${task.savedPath!}.part';
    if (partPath != null) {
      final part = File(partPath);
      if (await part.exists()) await part.delete();
    }
    task.status = DownloadStatus.queued;
    task.progress = 0;
    task.receivedBytes = 0;
    task.totalBytes = 0;
    task.speedBytesPerSecond = 0;
    task.errorMessage = null;
    task.savedPath = null;
    notifyListeners();
    _pumpQueue();
  }

  void removeTask(String taskId) {
    cancelDownload(taskId);
    _tasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
  }

  void clearCompleted() {
    _tasks.removeWhere((task) => task.status == DownloadStatus.completed);
    notifyListeners();
  }

  void clearFailedAndCanceled() {
    _tasks.removeWhere(
      (task) =>
          task.status == DownloadStatus.failed ||
          task.status == DownloadStatus.canceled,
    );
    notifyListeners();
  }

  DownloadTask? _findTask(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<String> _resolveRemoteFileName(
    String url,
    String requestedName,
    CancelToken cancelToken,
    Map<String, String> requestHeaders,
  ) async {
    var candidate = _sanitizeFileName(requestedName);
    try {
      final response = await _dio.head<void>(
        url,
        cancelToken: cancelToken,
        options: Options(
          receiveDataWhenStatusError: false,
          headers: <String, dynamic>{
            HttpHeaders.acceptEncodingHeader: 'identity',
            ...requestHeaders,
          },
          followRedirects: true,
          maxRedirects: 10,
        ),
      );
      final disposition = response.headers.value('content-disposition');
      final headerName = _fileNameFromContentDisposition(disposition);
      if (headerName != null && headerName.isNotEmpty) {
        return _sanitizeFileName(headerName);
      }
      if (p.extension(candidate).isEmpty) {
        final extension = _extensionForContentType(
          response.headers.value(Headers.contentTypeHeader),
        );
        if (extension != null) candidate = '$candidate$extension';
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
    }
    return candidate;
  }

  String? _fileNameFromContentDisposition(String? value) {
    if (value == null || value.isEmpty) return null;
    final utf8Match = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(value);
    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!.trim());
    }
    final quotedMatch = RegExp(
      r'filename="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(value);
    if (quotedMatch != null) return quotedMatch.group(1)?.trim();
    final plainMatch = RegExp(
      r'filename=([^;]+)',
      caseSensitive: false,
    ).firstMatch(value);
    return plainMatch?.group(1)?.trim().replaceAll('"', '');
  }

  String? _extensionForContentType(String? value) {
    final type = value?.split(';').first.trim().toLowerCase();
    return switch (type) {
      'application/pdf' => '.pdf',
      'application/zip' => '.zip',
      'application/json' => '.json',
      'application/vnd.android.package-archive' => '.apk',
      'application/x-iso9660-image' => '.iso',
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      'video/mp4' => '.mp4',
      'video/webm' => '.webm',
      'text/html' => '.html',
      'text/plain' => '.txt',
      'audio/mpeg' => '.mp3',
      'audio/mp4' => '.m4a',
      _ => null,
    };
  }

  Future<Directory> _resolveTargetDirectory() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) return Directory(p.join(external.path, 'Filexa'));
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'Filexa'));
  }

  Future<String> _uniquePath(String directory, String fileName) async {
    var candidate = p.join(directory, fileName);
    if (!await File(candidate).exists() &&
        !await File('$candidate.part').exists()) {
      return candidate;
    }
    final extension = p.extension(fileName);
    final baseName = p.basenameWithoutExtension(fileName);
    var index = 1;
    while (await File(candidate).exists() ||
        await File('$candidate.part').exists()) {
      candidate = p.join(directory, '$baseName ($index)$extension');
      index++;
    }
    return candidate;
  }

  String _sanitizeFileName(String value) {
    var result = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (result.isEmpty) result = 'downloaded_file';
    return result;
  }

  String _friendlyDioMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) return 'Server returned HTTP $statusCode.';
    return switch (error.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out.',
      DioExceptionType.sendTimeout => 'Upload timed out.',
      DioExceptionType.receiveTimeout => 'Download timed out.',
      DioExceptionType.connectionError => 'No internet connection.',
      DioExceptionType.badCertificate => 'The server certificate is invalid.',
      _ => 'Could not download this file.',
    };
  }
}
