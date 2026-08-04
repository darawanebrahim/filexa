import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'code_document_viewer.dart';

class HtmlDocumentViewer extends StatefulWidget {
  const HtmlDocumentViewer({super.key, required this.path});
  final String path;

  @override
  State<HtmlDocumentViewer> createState() => _HtmlDocumentViewerState();
}

class _HtmlDocumentViewerState extends State<HtmlDocumentViewer> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _error = error.description);
          },
        ),
      )
      ..loadFile(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.path), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _controller.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'View source',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CodeDocumentViewer(path: widget.path),
              ),
            ),
            icon: const Icon(Icons.code_rounded),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: () => SharePlus.instance.share(
              ShareParams(files: [XFile(widget.path)]),
            ),
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
            Expanded(
              child: _error == null
                  ? WebViewWidget(controller: _controller)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.web_asset_off_rounded, size: 52),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() => _error = null);
                                _controller.loadFile(widget.path);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
