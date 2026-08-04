import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

enum LinkKind { directFile, webPage, protected, unavailable, unknown }

class LinkAnalysis {
  const LinkAnalysis({
    required this.kind,
    required this.finalUrl,
    required this.statusCode,
    required this.contentType,
    required this.contentLength,
    required this.suggestedFileName,
    required this.message,
  });

  final LinkKind kind;
  final String finalUrl;
  final int? statusCode;
  final String? contentType;
  final int? contentLength;
  final String? suggestedFileName;
  final String message;

  bool get canDownload => kind == LinkKind.directFile;
  bool get isWebPage => kind == LinkKind.webPage;
}

class LinkAnalyzer {
  LinkAnalyzer._();

  static final LinkAnalyzer instance = LinkAnalyzer._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: true,
      maxRedirects: 8,
      validateStatus: (status) => status != null && status < 600,
      headers: const <String, dynamic>{
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
        HttpHeaders.acceptEncodingHeader: 'identity',
      },
    ),
  );

  Future<LinkAnalysis> analyze(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return const LinkAnalysis(
        kind: LinkKind.unavailable,
        finalUrl: '',
        statusCode: null,
        contentType: null,
        contentLength: null,
        suggestedFileName: null,
        message: 'This is not a valid HTTP or HTTPS link.',
      );
    }

    try {
      Response<dynamic> response = await _dio.head<void>(uri.toString());
      if (response.statusCode == 405 || response.statusCode == 501) {
        response = await _dio.get<ResponseBody>(
          uri.toString(),
          options: Options(
            responseType: ResponseType.stream,
            headers: const <String, dynamic>{
              HttpHeaders.rangeHeader: 'bytes=0-0',
            },
          ),
        );
      }

      final status = response.statusCode;
      final finalUrl = response.realUri.toString();
      final type = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final length = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      final disposition = response.headers.value('content-disposition');
      final headerName = _fileNameFromDisposition(disposition);
      final urlName = _fileNameFromUrl(response.realUri);
      final suggestedName = headerName ?? urlName ?? _nameForType(type);

      if (status == 401 || status == 403) {
        return LinkAnalysis(
          kind: LinkKind.protected,
          finalUrl: finalUrl,
          statusCode: status,
          contentType: type,
          contentLength: length,
          suggestedFileName: suggestedName,
          message: 'This link requires permission, login, or a valid session.',
        );
      }
      if (status == 404 || status == 410) {
        return LinkAnalysis(
          kind: LinkKind.unavailable,
          finalUrl: finalUrl,
          statusCode: status,
          contentType: type,
          contentLength: length,
          suggestedFileName: suggestedName,
          message: 'The file is unavailable or the link has expired.',
        );
      }
      if (status != null && status >= 400) {
        return LinkAnalysis(
          kind: LinkKind.unavailable,
          finalUrl: finalUrl,
          statusCode: status,
          contentType: type,
          contentLength: length,
          suggestedFileName: suggestedName,
          message: 'The server rejected this request (HTTP $status).',
        );
      }

      final pageLike = type == 'text/html' || type == 'application/xhtml+xml';
      if (pageLike && !_looksLikeDownload(response.realUri, disposition)) {
        return LinkAnalysis(
          kind: LinkKind.webPage,
          finalUrl: finalUrl,
          statusCode: status,
          contentType: type,
          contentLength: length,
          suggestedFileName: suggestedName,
          message: 'This is a web page, not a direct downloadable file.',
        );
      }

      return LinkAnalysis(
        kind: LinkKind.directFile,
        finalUrl: finalUrl,
        statusCode: status,
        contentType: type,
        contentLength: length,
        suggestedFileName: suggestedName,
        message: 'Direct file link detected. Ready to download.',
      );
    } on DioException catch (error) {
      final message = switch (error.type) {
        DioExceptionType.connectionTimeout => 'Connection timed out.',
        DioExceptionType.receiveTimeout => 'The server took too long to respond.',
        DioExceptionType.connectionError => 'No network connection or server unavailable.',
        DioExceptionType.badCertificate => 'The server certificate is not trusted.',
        _ => 'The link could not be analyzed.',
      };
      return LinkAnalysis(
        kind: LinkKind.unavailable,
        finalUrl: uri.toString(),
        statusCode: error.response?.statusCode,
        contentType: null,
        contentLength: null,
        suggestedFileName: _fileNameFromUrl(uri),
        message: message,
      );
    } catch (_) {
      return LinkAnalysis(
        kind: LinkKind.unknown,
        finalUrl: uri.toString(),
        statusCode: null,
        contentType: null,
        contentLength: null,
        suggestedFileName: _fileNameFromUrl(uri),
        message: 'The link type could not be confirmed.',
      );
    }
  }

  bool _looksLikeDownload(Uri uri, String? disposition) {
    if (disposition?.toLowerCase().contains('attachment') == true) return true;
    return p.extension(uri.path).isNotEmpty;
  }

  String? _fileNameFromDisposition(String? value) {
    if (value == null || value.isEmpty) return null;
    final utf8 = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
        .firstMatch(value);
    if (utf8 != null) return Uri.decodeComponent(utf8.group(1)!.trim());
    final quoted = RegExp(r'filename="([^"]+)"', caseSensitive: false)
        .firstMatch(value);
    if (quoted != null) return quoted.group(1)?.trim();
    final plain = RegExp(r'filename=([^;]+)', caseSensitive: false)
        .firstMatch(value);
    return plain?.group(1)?.trim().replaceAll('"', '');
  }

  String? _fileNameFromUrl(Uri uri) {
    if (uri.pathSegments.isEmpty) return null;
    final last = Uri.decodeComponent(uri.pathSegments.last).trim();
    return last.isEmpty || p.extension(last).isEmpty ? null : last;
  }

  String _nameForType(String? type) {
    final extension = switch (type) {
      'application/pdf' => '.pdf',
      'application/zip' => '.zip',
      'application/json' => '.json',
      'application/vnd.android.package-archive' => '.apk',
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      'video/mp4' => '.mp4',
      'audio/mpeg' => '.mp3',
      'text/plain' => '.txt',
      'text/html' => '.html',
      _ => '',
    };
    return 'download_${DateTime.now().millisecondsSinceEpoch}$extension';
  }
}
