import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class OfficeDocumentService {
  const OfficeDocumentService();

  Future<String> readDocxText(String path) async {
    final archive = await _decode(path);
    final file = _file(archive, 'word/document.xml');
    if (file == null) throw FileSystemException('Invalid DOCX: document.xml is missing.');
    final document = XmlDocument.parse(utf8.decode(_bytes(file)));
    final paragraphs = <String>[];
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'p') continue;
      final text = element.descendants
          .whereType<XmlElement>()
          .where((node) => node.name.local == 't')
          .map((node) => node.innerText)
          .join();
      if (text.isNotEmpty) paragraphs.add(text);
    }
    return paragraphs.join('\n');
  }

  Future<List<List<String>>> readXlsxGrid(String path) async {
    final archive = await _decode(path);
    final shared = <String>[];
    final sharedFile = _file(archive, 'xl/sharedStrings.xml');
    if (sharedFile != null) {
      final doc = XmlDocument.parse(utf8.decode(_bytes(sharedFile)));
      for (final si in doc.descendants.whereType<XmlElement>().where((e) => e.name.local == 'si')) {
        shared.add(si.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == 't')
            .map((e) => e.innerText)
            .join());
      }
    }

    final sheetFile = _file(archive, 'xl/worksheets/sheet1.xml');
    if (sheetFile == null) throw FileSystemException('Invalid XLSX: sheet1.xml is missing.');
    final doc = XmlDocument.parse(utf8.decode(_bytes(sheetFile)));
    final result = <List<String>>[];
    for (final row in doc.descendants.whereType<XmlElement>().where((e) => e.name.local == 'row')) {
      final cells = <int, String>{};
      var maxCol = -1;
      for (final cell in row.children.whereType<XmlElement>().where((e) => e.name.local == 'c')) {
        final ref = cell.getAttribute('r') ?? '';
        final col = _columnIndex(ref);
        if (col < 0) continue;
        maxCol = col > maxCol ? col : maxCol;
        final type = cell.getAttribute('t');
        String value = '';
        if (type == 'inlineStr') {
          value = cell.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join();
        } else {
          XmlElement? valueNode;
          for (final node in cell.descendants.whereType<XmlElement>()) {
            if (node.name.local == 'v') { valueNode = node; break; }
          }
          value = valueNode?.innerText ?? '';
          if (type == 's') {
            final index = int.tryParse(value);
            if (index != null && index >= 0 && index < shared.length) value = shared[index];
          }
        }
        cells[col] = value;
      }
      if (maxCol >= 0) {
        result.add(List<String>.generate(maxCol + 1, (index) => cells[index] ?? ''));
      }
    }
    return result;
  }

  Future<List<String>> readPptxSlides(String path) async {
    final archive = await _decode(path);
    final slideFiles = archive.files
        .where((file) => file.name.startsWith('ppt/slides/slide') && file.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => _slideNumber(a.name).compareTo(_slideNumber(b.name)));
    final slides = <String>[];
    for (final file in slideFiles) {
      final doc = XmlDocument.parse(utf8.decode(_bytes(file)));
      final text = doc.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 't')
          .map((e) => e.innerText.trim())
          .where((value) => value.isNotEmpty)
          .join('\n');
      slides.add(text);
    }
    return slides;
  }

  Future<void> writeDocx(String path, String text) async {
    final archive = Archive();
    _addText(archive, '[Content_Types].xml', _docxContentTypes);
    _addText(archive, '_rels/.rels', _docxRootRels);
    _addText(archive, 'word/document.xml', _docxDocument(text));
    final encoded = ZipEncoder().encode(archive);
    await File(path).writeAsBytes(encoded, flush: true);
  }

  Future<void> writeXlsx(String path, List<List<String>> grid) async {
    final archive = Archive();
    _addText(archive, '[Content_Types].xml', _xlsxContentTypes);
    _addText(archive, '_rels/.rels', _xlsxRootRels);
    _addText(archive, 'xl/workbook.xml', _xlsxWorkbook);
    _addText(archive, 'xl/_rels/workbook.xml.rels', _xlsxWorkbookRels);
    _addText(archive, 'xl/worksheets/sheet1.xml', _xlsxSheet(grid));
    final encoded = ZipEncoder().encode(archive);
    await File(path).writeAsBytes(encoded, flush: true);
  }

  Future<void> exportTextPdf(String path, String text, {String title = 'Filexa document'}) async {
    final document = PdfDocument();
    final page = document.pages.add();
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    page.graphics.drawString(title, titleFont, bounds: const Rect.fromLTWH(0, 0, 500, 30));
    final element = PdfTextElement(text: text.isEmpty ? ' ' : text, font: bodyFont);
    element.draw(page: page, bounds: const Rect.fromLTWH(0, 42, 500, 700));
    final bytes = await document.save();
    document.dispose();
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<void> exportGridPdf(String path, List<List<String>> grid, {String title = 'Filexa spreadsheet'}) async {
    final document = PdfDocument();
    final page = document.pages.add();
    page.graphics.drawString(
      title,
      PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold),
      bounds: const Rect.fromLTWH(0, 0, 500, 28),
    );
    final pdfGrid = PdfGrid();
    final columnCount = grid.fold<int>(1, (max, row) => row.length > max ? row.length : max);
    pdfGrid.columns.add(count: columnCount);
    for (final row in grid) {
      final pdfRow = pdfGrid.rows.add();
      for (var i = 0; i < columnCount; i++) {
        pdfRow.cells[i].value = i < row.length ? row[i] : '';
      }
    }
    pdfGrid.style = PdfGridStyle(font: PdfStandardFont(PdfFontFamily.helvetica, 9));
    pdfGrid.draw(page: page, bounds: const Rect.fromLTWH(0, 38, 500, 700));
    final bytes = await document.save();
    document.dispose();
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<Archive> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    return ZipDecoder().decodeBytes(bytes, verify: true);
  }

  ArchiveFile? _file(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.name == name) return file;
    }
    return null;
  }

  Uint8List _bytes(ArchiveFile file) => file.content;

  void _addText(Archive archive, String name, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  int _columnIndex(String reference) {
    final letters = RegExp(r'^[A-Za-z]+').stringMatch(reference);
    if (letters == null) return -1;
    var value = 0;
    for (final code in letters.toUpperCase().codeUnits) {
      value = value * 26 + (code - 64);
    }
    return value - 1;
  }

  int _slideNumber(String name) => int.tryParse(RegExp(r'slide(\d+)').firstMatch(name)?.group(1) ?? '') ?? 0;

  String _xml(String value) => const HtmlEscape(HtmlEscapeMode.element).convert(value);

  String _docxDocument(String text) {
    final paragraphs = text.split('\n').map((line) {
      final preserve = line.startsWith(' ') || line.endsWith(' ');
      return '<w:p><w:r><w:t${preserve ? ' xml:space="preserve"' : ''}>${_xml(line)}</w:t></w:r></w:p>';
    }).join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$paragraphs<w:sectPr/></w:body></w:document>';
  }

  String _xlsxSheet(List<List<String>> grid) {
    final rows = <String>[];
    for (var r = 0; r < grid.length; r++) {
      final cells = <String>[];
      for (var c = 0; c < grid[r].length; c++) {
        final value = grid[r][c];
        final ref = '${_columnName(c)}${r + 1}';
        cells.add('<c r="$ref" t="inlineStr"><is><t>${_xml(value)}</t></is></c>');
      }
      rows.add('<row r="${r + 1}">${cells.join()}</row>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>${rows.join()}</sheetData></worksheet>';
  }

  String _columnName(int index) {
    var number = index + 1;
    var result = '';
    while (number > 0) {
      final remainder = (number - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      number = (number - 1) ~/ 26;
    }
    return result;
  }
}

const _docxContentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

const _docxRootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

const _xlsxContentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';

const _xlsxRootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

const _xlsxWorkbook = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>''';

const _xlsxWorkbookRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';
