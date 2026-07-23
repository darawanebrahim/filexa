enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.folder,
    required this.createdAt,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSecond = 0,
    this.savedPath,
    this.errorMessage,
    this.headers = const <String, String>{},
  });

  final String id;
  final String url;
  String fileName;
  final String folder;
  final DateTime createdAt;

  DownloadStatus status;
  double progress;
  int receivedBytes;
  int totalBytes;
  double speedBytesPerSecond;
  String? savedPath;
  String? errorMessage;
  final Map<String, String> headers;

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  bool get canPause => status == DownloadStatus.downloading;
  bool get canResume => status == DownloadStatus.paused;

  Duration? get estimatedRemaining {
    if (totalBytes <= 0 || speedBytesPerSecond <= 0) return null;
    final remainingBytes = totalBytes - receivedBytes;
    if (remainingBytes <= 0) return Duration.zero;
    return Duration(seconds: (remainingBytes / speedBytesPerSecond).ceil());
  }
}
