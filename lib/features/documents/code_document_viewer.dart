import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class CodeDocumentViewer extends StatefulWidget {
  const CodeDocumentViewer({
    super.key,
    required this.path,
    this.initialSearch,
  });

  final String path;
  final String? initialSearch;

  @override
  State<CodeDocumentViewer> createState() => _CodeDocumentViewerState();
}

class _CodeDocumentViewerState extends State<CodeDocumentViewer> {
  final TextEditingController _searchController = TextEditingController();
  String _content = '';
  String? _error;
  bool _loading = true;
  bool _wrapLines = true;
  bool _showLineNumbers = true;
  double _fontSize = 13;
  int _matches = 0;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearch ?? '';
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final text = await File(widget.path).readAsString();
      if (!mounted) return;
      setState(() {
        _content = text;
        _loading = false;
      });
      _countMatches();
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read this file: $error';
        _loading = false;
      });
    }
  }

  void _countMatches() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      if (_matches != 0) setState(() => _matches = 0);
      return;
    }
    var count = 0;
    var start = 0;
    final source = _content.toLowerCase();
    while (true) {
      final index = source.indexOf(query, start);
      if (index < 0) break;
      count++;
      start = index + query.length;
    }
    setState(() => _matches = count);
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Code copied.')));
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.path)],
        text: p.basename(widget.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fileName = p.basename(widget.path);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              _languageLabel(p.extension(fileName)),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            onPressed: _loading || _error != null ? null : _copyAll,
            icon: const Icon(Icons.copy_all_rounded),
          ),
          IconButton(
            tooltip: 'Share file',
            onPressed: _share,
            icon: const Icon(Icons.share_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'wrap':
                  setState(() => _wrapLines = !_wrapLines);
                  break;
                case 'lines':
                  setState(() => _showLineNumbers = !_showLineNumbers);
                  break;
                case 'smaller':
                  setState(() => _fontSize = (_fontSize - 1).clamp(10, 24).toDouble());
                  break;
                case 'larger':
                  setState(() => _fontSize = (_fontSize + 1).clamp(10, 24).toDouble());
                  break;
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'wrap',
                checked: _wrapLines,
                child: const Text('Wrap long lines'),
              ),
              CheckedPopupMenuItem(
                value: 'lines',
                checked: _showLineNumbers,
                child: const Text('Line numbers'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'smaller', child: Text('Smaller text')),
              const PopupMenuItem(value: 'larger', child: Text('Larger text')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _countMatches(),
                decoration: InputDecoration(
                  hintText: 'Find in file',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Center(
                            widthFactor: 1,
                            child: Text('$_matches match${_matches == 1 ? '' : 'es'}'),
                          ),
                        ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ViewerError(message: _error!, onRetry: _load)
                      : Container(
                          width: double.infinity,
                          color: colors.surfaceContainerLowest,
                          child: _CodePane(
                            content: _content,
                            query: _searchController.text.trim(),
                            fontSize: _fontSize,
                            wrapLines: _wrapLines,
                            showLineNumbers: _showLineNumbers,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  static String _languageLabel(String extension) => switch (extension.toLowerCase()) {
        '.html' || '.htm' => 'HTML document',
        '.css' => 'CSS stylesheet',
        '.js' || '.mjs' => 'JavaScript source',
        '.json' => 'JSON data',
        '.xml' => 'XML document',
        '.php' => 'PHP source (view only)',
        '.md' || '.markdown' => 'Markdown document',
        '.yaml' || '.yml' => 'YAML document',
        '.dart' => 'Dart source',
        '.txt' || '.log' => 'Plain text',
        _ => 'Source file',
      };
}

class _CodePane extends StatelessWidget {
  const _CodePane({
    required this.content,
    required this.query,
    required this.fontSize,
    required this.wrapLines,
    required this.showLineNumbers,
  });

  final String content;
  final String query;
  final double fontSize;
  final bool wrapLines;
  final bool showLineNumbers;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final code = ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 40),
      itemCount: lines.length,
      itemBuilder: (context, index) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLineNumbers)
            SizedBox(
              width: 48,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 1),
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: fontSize - 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _HighlightedLine(
              text: lines[index],
              query: query,
              fontSize: fontSize,
              softWrap: wrapLines,
            ),
          ),
        ],
      ),
    );

    if (wrapLines) return code;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1400,
        child: code,
      ),
    );
  }
}

class _HighlightedLine extends StatelessWidget {
  const _HighlightedLine({
    required this.text,
    required this.query,
    required this.fontSize,
    required this.softWrap,
  });

  final String text;
  final String query;
  final double fontSize;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.45,
      color: Theme.of(context).colorScheme.onSurface,
    );
    if (query.isEmpty) {
      return SelectableText(text, style: baseStyle, maxLines: softWrap ? null : 1);
    }
    final lower = text.toLowerCase();
    final target = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lower.indexOf(target, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = index + query.length;
    }
    return SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: softWrap ? null : 1,
    );
  }
}

class _ViewerError extends StatelessWidget {
  const _ViewerError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
