import 'package:dio/dio.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<void> download({
    required String url,
    required String savePath,
    required void Function(int received, int total) onProgress,
  }) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
    );
  }
}