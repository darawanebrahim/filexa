import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfToolResult {
  const PdfToolResult({required this.path, required this.pageCount});

  final String path;
  final int pageCount;
}

class PdfInfo {
  const PdfInfo({
    required this.pageCount,
    required this.fileSize,
    required this.title,
    required this.author,
    required this.subject,
  });

  final int pageCount;
  final int fileSize;
  final String? title;
  final String? author;
  final String? subject;
}

class PdfToolsService {
  const PdfToolsService();

  Future<PdfInfo> inspect(String sourcePath) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final info = document.documentInformation;
      return PdfInfo(
        pageCount: document.pages.count,
        fileSize: bytes.length,
        title: _clean(info.title),
        author: _clean(info.author),
        subject: _clean(info.subject),
      );
    } finally {
      document.dispose();
    }
  }

  Future<String> extractText(String sourcePath) async {
    final document = PdfDocument(inputBytes: await File(sourcePath).readAsBytes());
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  Future<PdfToolResult> saveAsCopy(String sourcePath, {String? preferredName}) async {
    final output = await _uniqueOutputPath(
      sourcePath,
      preferredName ?? '${p.basenameWithoutExtension(sourcePath)}_copy.pdf',
    );
    await File(sourcePath).copy(output);
    final info = await inspect(output);
    return PdfToolResult(path: output, pageCount: info.pageCount);
  }

  Future<PdfToolResult> rotatePages(
    String sourcePath, {
    required Set<int> pageIndexes,
    int clockwiseDegrees = 90,
  }) async {
    final document = PdfDocument(inputBytes: await File(sourcePath).readAsBytes());
    try {
      final selected = pageIndexes.isEmpty
          ? <int>{for (var i = 0; i < document.pages.count; i++) i}
          : pageIndexes.where((i) => i >= 0 && i < document.pages.count).toSet();
      for (final index in selected) {
        final page = document.pages[index];
        page.rotation = _rotate(page.rotation, clockwiseDegrees);
      }
      final output = await _uniqueOutputPath(
        sourcePath,
        '${p.basenameWithoutExtension(sourcePath)}_rotated.pdf',
      );
      await File(output).writeAsBytes(await document.save(), flush: true);
      return PdfToolResult(path: output, pageCount: document.pages.count);
    } finally {
      document.dispose();
    }
  }

  Future<PdfToolResult> deletePages(
    String sourcePath, {
    required Set<int> pageIndexes,
  }) async {
    final document = PdfDocument(inputBytes: await File(sourcePath).readAsBytes());
    try {
      final valid = pageIndexes
          .where((i) => i >= 0 && i < document.pages.count)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      if (valid.isEmpty) throw const FormatException('Choose at least one valid page.');
      if (valid.length >= document.pages.count) {
        throw const FormatException('A PDF must keep at least one page.');
      }
      for (final index in valid) {
        document.pages.removeAt(index);
      }
      final output = await _uniqueOutputPath(
        sourcePath,
        '${p.basenameWithoutExtension(sourcePath)}_trimmed.pdf',
      );
      await File(output).writeAsBytes(await document.save(), flush: true);
      return PdfToolResult(path: output, pageCount: document.pages.count);
    } finally {
      document.dispose();
    }
  }

  Future<PdfToolResult> extractPages(
    String sourcePath, {
    required List<int> pageIndexes,
    String? outputName,
  }) async {
    final source = PdfDocument(inputBytes: await File(sourcePath).readAsBytes());
    final destination = PdfDocument();
    try {
      final valid = pageIndexes
          .where((i) => i >= 0 && i < source.pages.count)
          .toList(growable: false);
      if (valid.isEmpty) throw const FormatException('Choose at least one valid page.');
      for (final index in valid) {
        _copyPage(source.pages[index], destination);
      }
      final output = await _uniqueOutputPath(
        sourcePath,
        outputName ?? '${p.basenameWithoutExtension(sourcePath)}_pages.pdf',
      );
      await File(output).writeAsBytes(await destination.save(), flush: true);
      return PdfToolResult(path: output, pageCount: destination.pages.count);
    } finally {
      destination.dispose();
      source.dispose();
    }
  }

  Future<PdfToolResult> merge(List<String> sourcePaths, {String? outputName}) async {
    if (sourcePaths.length < 2) {
      throw const FormatException('Choose at least two PDF files to merge.');
    }
    final destination = PdfDocument();
    try {
      var pages = 0;
      for (final sourcePath in sourcePaths) {
        final source = PdfDocument(inputBytes: await File(sourcePath).readAsBytes());
        try {
          for (var index = 0; index < source.pages.count; index++) {
            _copyPage(source.pages[index], destination);
            pages++;
          }
        } finally {
          source.dispose();
        }
      }
      final firstPath = sourcePaths.first;
      final output = await _uniqueOutputPath(
        firstPath,
        outputName ?? '${p.basenameWithoutExtension(firstPath)}_merged.pdf',
      );
      await File(output).writeAsBytes(await destination.save(), flush: true);
      return PdfToolResult(path: output, pageCount: pages);
    } finally {
      destination.dispose();
    }
  }

  List<int> parsePageSelection(String input, int pageCount) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return <int>[];
    final result = <int>{};
    for (final token in trimmed.split(',')) {
      final part = token.trim();
      if (part.isEmpty) continue;
      if (part.contains('-')) {
        final bits = part.split('-').map((e) => int.tryParse(e.trim())).toList();
        if (bits.length != 2 || bits[0] == null || bits[1] == null) {
          throw FormatException('Invalid page range: $part');
        }
        final start = bits[0]!;
        final end = bits[1]!;
        if (start <= 0 || end <= 0 || start > end) {
          throw FormatException('Invalid page range: $part');
        }
        for (var page = start; page <= end; page++) {
          if (page <= pageCount) result.add(page - 1);
        }
      } else {
        final page = int.tryParse(part);
        if (page == null || page <= 0) throw FormatException('Invalid page: $part');
        if (page <= pageCount) result.add(page - 1);
      }
    }
    final ordered = result.toList()..sort();
    return ordered;
  }

  void _copyPage(PdfPage sourcePage, PdfDocument destination) {
    final section = destination.sections!.add();
    section.pageSettings
      ..size = sourcePage.size
      ..margins.all = 0;
    final target = section.pages.add();
    final template = sourcePage.createTemplate();
    target.graphics.drawPdfTemplate(template, Offset.zero, sourcePage.size);
  }

  PdfPageRotateAngle _rotate(PdfPageRotateAngle current, int degrees) {
    final currentDegrees = switch (current) {
      PdfPageRotateAngle.rotateAngle0 => 0,
      PdfPageRotateAngle.rotateAngle90 => 90,
      PdfPageRotateAngle.rotateAngle180 => 180,
      PdfPageRotateAngle.rotateAngle270 => 270,
    };
    final normalized = (currentDegrees + degrees) % 360;
    return switch (normalized) {
      90 => PdfPageRotateAngle.rotateAngle90,
      180 => PdfPageRotateAngle.rotateAngle180,
      270 => PdfPageRotateAngle.rotateAngle270,
      _ => PdfPageRotateAngle.rotateAngle0,
    };
  }

  Future<String> _uniqueOutputPath(String sourcePath, String requestedName) async {
    final directory = p.dirname(sourcePath);
    final safe = requestedName.toLowerCase().endsWith('.pdf')
        ? requestedName
        : '$requestedName.pdf';
    var candidate = p.join(directory, safe);
    var counter = 1;
    while (await File(candidate).exists()) {
      final stem = p.basenameWithoutExtension(safe);
      candidate = p.join(directory, '$stem ($counter).pdf');
      counter++;
    }
    return candidate;
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
