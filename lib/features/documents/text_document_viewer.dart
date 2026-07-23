import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_item.dart';

class TextDocumentViewer extends StatefulWidget {
  const TextDocumentViewer({super.key, required this.item});
  final FileItem item;

  @override
  State<TextDocumentViewer> createState() => _TextDocumentViewerState();
}

class _TextDocumentViewerState extends State<TextDocumentViewer> {
  late final Future<String> _content = _readContent();
  double _fontSize = 16;
  bool _wrap = true;

  Future<String> _readContent() async {
    const maxBytes = 2 * 1024 * 1024;
    final file = File(widget.item.path);
    final length = await file.length();
    if (length > maxBytes) {
      throw const FileSystemException('This text file is larger than the 2 MB in-app reading limit.');
    }
    return file.readAsString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => Share.shareXFiles([XFile(widget.item.path)], subject: widget.item.name),
            icon: const Icon(Icons.share_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'smaller') _fontSize = (_fontSize - 2).clamp(12, 28).toDouble();
                if (value == 'larger') _fontSize = (_fontSize + 2).clamp(12, 28).toDouble();
                if (value == 'wrap') _wrap = !_wrap;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'smaller', child: Text('Smaller text')),
              const PopupMenuItem(value: 'larger', child: Text('Larger text')),
              PopupMenuItem(value: 'wrap', child: Text(_wrap ? 'Disable line wrap' : 'Enable line wrap')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final text = snapshot.data ?? '';
          final content = SelectableText(text, style: TextStyle(fontSize: _fontSize, height: 1.55));
          return Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: _wrap ? Axis.vertical : Axis.horizontal,
              padding: const EdgeInsets.all(20),
              child: _wrap ? content : SingleChildScrollView(child: content),
            ),
          );
        },
      ),
    );
  }
}
