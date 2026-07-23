import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/download_manager.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserTab {
  _BrowserTab({required this.id, required this.controller, required this.url});
  final String id;
  final WebViewController controller;
  String url;
  String title = 'New tab';
  int progress = 0;
  bool loading = true;
  bool canGoBack = false;
  bool canGoForward = false;
  bool desktopMode = false;
}

class _BrowserPageState extends State<BrowserPage> with WidgetsBindingObserver {
  static const _homeUrl = 'filexa://home';
  static const _searchUrl = 'https://www.google.com';
  static const _downloadChannel = 'FilexaDownload';
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';
  static const _extensions = <String>{
    'apk',
    'avi',
    'doc',
    'docx',
    'epub',
    'flac',
    'gif',
    'iso',
    'jpg',
    'jpeg',
    'm4a',
    'mkv',
    'mov',
    'mp3',
    'mp4',
    'mpeg',
    'pdf',
    'png',
    'ppt',
    'pptx',
    'rar',
    'svg',
    'tar',
    'txt',
    'wav',
    'webm',
    'webp',
    'xls',
    'xlsx',
    'zip',
    '7z',
  };

  final _addressController = TextEditingController();
  final _addressFocus = FocusNode();
  final List<_BrowserTab> _tabs = [];
  final List<String> _history = [];
  final Set<String> _bookmarks = {};
  final List<String> _closedTabs = [];
  final Map<String, int> _visitCounts = {};
  int _currentIndex = 0;
  bool _checkingClipboard = false;
  String? _lastClipboardUrl;
  String? _clipboardUrl;

  _BrowserTab get _tab => _tabs[_currentIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _addTab(_homeUrl, switchToIt: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _addressController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  void _addTab(String url, {bool switchToIt = true}) {
    late _BrowserTab tab;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUserAgent)
      ..setBackgroundColor(const Color(0xFFF7F6FB))
      ..addJavaScriptChannel(
        _downloadChannel,
        onMessageReceived: (message) {
          final value = message.message.trim();
          if (_isWebUrl(value)) {
            _handleDetectedDownload(value);
          } else if (value.startsWith('blob:')) {
            _showUnsupportedBlobMessage();
          }
        },
      );
    tab = _BrowserTab(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      controller: controller,
      url: url,
    );
    controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => _handleNavigation(tab, request),
          onProgress: (value) {
            if (!mounted) return;
            setState(() {
              tab.progress = value;
              tab.loading = value < 100;
            });
          },
          onPageStarted: (value) {
            if (!mounted) return;
            setState(() {
              tab.url = value;
              tab.loading = true;
            });
            if (_tab.id == tab.id) _addressController.text = value;
            _refreshTab(tab);
          },
          onPageFinished: (value) async {
            final title = await tab.controller.getTitle();
            if (!mounted) return;
            _recordHistory(value);
            setState(() {
              tab.url = value;
              tab.title = (title == null || title.trim().isEmpty)
                  ? _host(value)
                  : title;
              tab.loading = false;
              tab.progress = 100;
            });
            if (_tab.id == tab.id) _addressController.text = value;
            await _installDownloadInterceptor(tab);
            await _applyPageMode(tab);
            _refreshTab(tab);
          },
        ),
      );
    if (url != _homeUrl) {
      controller.loadRequest(Uri.parse(url));
    } else {
      tab.loading = false;
      tab.title = 'New tab';
    }
    setState(() {
      _tabs.add(tab);
      if (switchToIt) _currentIndex = _tabs.length - 1;
      _addressController.text = url;
    });
  }

  Future<NavigationDecision> _handleNavigation(
    _BrowserTab tab,
    NavigationRequest request,
  ) async {
    final url = request.url;
    if (url.startsWith('blob:')) {
      await _showUnsupportedBlobMessage();
      return NavigationDecision.prevent;
    }
    if (!request.isMainFrame || !_looksDownloadable(url)) {
      return NavigationDecision.navigate;
    }
    final download = await _askDownload(url);
    return download ? NavigationDecision.prevent : NavigationDecision.navigate;
  }

  Future<void> _handleDetectedDownload(String url) async {
    if (!mounted) return;
    await _askDownload(url);
  }

  Future<void> _showUnsupportedBlobMessage() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This website uses a temporary blob link. Open the direct file link to download it.',
        ),
      ),
    );
  }

  Future<void> _installDownloadInterceptor(_BrowserTab tab) async {
    const script = r'''(() => {
  if (window.__filexaDownloadInterceptorInstalled) return;
  window.__filexaDownloadInterceptorInstalled = true;
  const extensions = /\.(apk|avi|docx?|epub|flac|gif|jpe?g|m4a|mkv|mov|mp3|mp4|mpeg|pdf|png|pptx?|rar|svg|tar|txt|wav|webm|webp|xlsx?|zip|7z|iso)(?:$|[?#])/i;
  document.addEventListener('click', (event) => {
    const anchor = event.target && event.target.closest
      ? event.target.closest('a[href]')
      : null;
    if (!anchor) return;
    const href = anchor.href || '';
    const downloadable = anchor.hasAttribute('download') || extensions.test(href) || href.startsWith('blob:');
    if (!downloadable) return;
    event.preventDefault();
    event.stopPropagation();
    FilexaDownload.postMessage(href);
  }, true);
})();''';
    try {
      await tab.controller.runJavaScript(script);
    } catch (_) {
      // Normal navigation detection remains active when injection is blocked.
    }
  }

  Future<void> _applyPageMode(_BrowserTab tab) async {
    final script = tab.desktopMode
        ? r'''(() => {
  document.querySelectorAll('meta[name="viewport"]').forEach((node) => node.remove());
  const viewport = document.createElement('meta');
  viewport.id = 'filexa-viewport';
  viewport.name = 'viewport';
  const desktopWidth = 1280;
  const scale = Math.max(0.25, Math.min(1, window.innerWidth / desktopWidth));
  viewport.content = `width=${desktopWidth}, initial-scale=${scale}, minimum-scale=0.2, maximum-scale=3, user-scalable=yes`;
  document.head.appendChild(viewport);
  document.documentElement.style.setProperty('min-width', `${desktopWidth}px`, 'important');
  document.body.style.setProperty('min-width', `${desktopWidth}px`, 'important');
  document.documentElement.style.setProperty('overflow-x', 'auto', 'important');
  document.body.style.setProperty('overflow-x', 'auto', 'important');
})();'''
        : r'''(() => {
  let viewport = document.querySelector('meta[name="viewport"]');
  if (!viewport) {
    viewport = document.createElement('meta');
    viewport.name = 'viewport';
    document.head.appendChild(viewport);
  }
  viewport.id = 'filexa-viewport';
  viewport.content = 'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes, viewport-fit=cover';

  // Remove every layout override previously applied by Filexa desktop/fit mode.
  document.documentElement.style.removeProperty('zoom');
  document.body.style.removeProperty('zoom');
  document.documentElement.style.removeProperty('transform');
  document.body.style.removeProperty('transform');
  document.documentElement.style.removeProperty('transform-origin');
  document.body.style.removeProperty('transform-origin');
  document.documentElement.style.removeProperty('width');
  document.body.style.removeProperty('width');
  document.documentElement.style.removeProperty('min-width');
  document.body.style.removeProperty('min-width');
  document.documentElement.style.removeProperty('max-width');
  document.body.style.removeProperty('max-width');
  document.documentElement.style.removeProperty('overflow-x');
  document.body.style.removeProperty('overflow-x');

  requestAnimationFrame(() => {
    window.scrollTo(0, window.scrollY || 0);
  });
})();''';
    try {
      await tab.controller.runJavaScript(script);
    } catch (_) {
      // Keep browsing even when a page blocks script injection.
    }
  }

  Future<void> _refreshTab(_BrowserTab tab) async {
    final back = await tab.controller.canGoBack();
    final forward = await tab.controller.canGoForward();
    if (!mounted) return;
    setState(() {
      tab.canGoBack = back;
      tab.canGoForward = forward;
    });
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
      _addressController.text = _tab.url;
    });
  }

  void _closeTab(int index) {
    final closingUrl = _tabs[index].url;
    if (closingUrl != _homeUrl) {
      _closedTabs.remove(closingUrl);
      _closedTabs.insert(0, closingUrl);
      if (_closedTabs.length > 10) _closedTabs.removeLast();
    }
    if (_tabs.length == 1) {
      _goHome();
      return;
    }
    setState(() {
      _tabs.removeAt(index);
      if (_currentIndex >= _tabs.length) {
        _currentIndex = _tabs.length - 1;
      } else if (index < _currentIndex) {
        _currentIndex--;
      }
      _addressController.text = _tab.url;
    });
  }

  void _closeAllTabs() {
    for (final tab in _tabs) {
      if (tab.url != _homeUrl) {
        _closedTabs.remove(tab.url);
        _closedTabs.insert(0, tab.url);
      }
    }
    if (_closedTabs.length > 10) {
      _closedTabs.removeRange(10, _closedTabs.length);
    }
    setState(() {
      _tabs.clear();
      _currentIndex = 0;
    });
    _addTab(_homeUrl, switchToIt: true);
  }

  void _reopenClosedTab() {
    if (_closedTabs.isEmpty) return;
    final url = _closedTabs.removeAt(0);
    _addTab(url, switchToIt: true);
  }

  String _normalize(String input) {
    final value = input.trim();
    if (value.isEmpty) return _searchUrl;
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) return value;
    if (value.contains('.') && !value.contains(' ')) return 'https://$value';
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(value)}';
  }

  Future<void> _openAddress() async {
    final url = _normalize(_addressController.text);
    FocusScope.of(context).unfocus();
    await _loadUrl(url);
  }

  Future<void> _loadUrl(String url) async {
    setState(() {
      _tab.url = url;
      _tab.title = _host(url);
      _tab.loading = true;
      _addressController.text = url;
    });
    await _tab.controller.loadRequest(Uri.parse(url));
  }

  void _goHome() {
    setState(() {
      _tab.url = _homeUrl;
      _tab.title = 'New tab';
      _tab.loading = false;
      _tab.progress = 0;
      _tab.canGoBack = false;
      _tab.canGoForward = false;
      _addressController.clear();
    });
  }

  bool _isWebUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool _looksDownloadable(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    final name = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last.toLowerCase();
    final dot = name.lastIndexOf('.');
    return dot > -1 && _extensions.contains(name.substring(dot + 1));
  }

  String _fileName(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final name = Uri.decodeComponent(uri.pathSegments.last).trim();
      final extension = name.contains('.') ? name.split('.').last : '';
      if (name.isNotEmpty &&
          extension.isNotEmpty &&
          _extensions.contains(extension.toLowerCase())) {
        return name;
      }
    }

    final host = uri?.host
        .replaceFirst('www.', '')
        .replaceFirst('m.', '')
        .split('.')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final prefix = (host == null || host.isEmpty) ? 'download' : host;
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _host(String url) {
    if (url == _homeUrl) return 'New tab';
    return Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? 'New tab';
  }

  void _recordHistory(String url) {
    if (!_isWebUrl(url)) return;
    _history.remove(url);
    _history.insert(0, url);
    _visitCounts[url] = (_visitCounts[url] ?? 0) + 1;
    if (_history.length > 50) _history.removeLast();
  }

  List<String> get _mostVisitedUrls {
    final entries = _visitCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(6).map((entry) => entry.key).toList();
  }

  Future<void> _toggleDesktopMode() async {
    final tab = _tab;
    final enableDesktop = !tab.desktopMode;
    final currentUrl = tab.url;

    tab.desktopMode = enableDesktop;
    await tab.controller.setUserAgent(
      enableDesktop ? _desktopUserAgent : _mobileUserAgent,
    );

    if (currentUrl != _homeUrl) {
      try {
        await tab.controller.runJavaScript(r'''(() => {
  document.documentElement.style.zoom = '';
  document.body.style.zoom = '';
  document.body.style.transform = '';
  document.body.style.width = '';
  window.scrollTo(0, 0);
})();''');
      } catch (_) {}

      await tab.controller.loadRequest(
        Uri.parse(currentUrl),
        headers: const <String, String>{
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );
    }

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enableDesktop ? 'Desktop mode enabled' : 'Mobile mode enabled',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _findInPage() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.manage_search_rounded),
        title: const Text('Find in page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Text to find'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Find'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || query.isEmpty) return;
    final encoded = jsonEncode(query);
    await _tab.controller.runJavaScript('window.find($encoded);');
  }

  Future<bool> _askDownload(String url) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.download_for_offline_rounded),
        title: const Text('Download detected'),
        content: Text(url, maxLines: 4, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Open page'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download'),
          ),
        ],
      ),
    );
    if (result == true) await _startDownload(url);
    return result ?? false;
  }

  Future<void> _startDownload(String url) async {
    if (!_isWebUrl(url)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is not a direct HTTP or HTTPS file link.'),
        ),
      );
      return;
    }
    final task = await DownloadManager.instance.startDownload(
      url: url,
      fileName: _fileName(url),
      folder: 'Filexa app storage',
      headers: <String, String>{
        'User-Agent': _tab.desktopMode
            ? _desktopUserAgent
            : _mobileUserAgent,
        if (_tab.url != _homeUrl) 'Referer': _tab.url,
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Downloading ${task.fileName}…')));
  }

  Future<void> _checkClipboard() async {
    if (_checkingClipboard || !mounted) return;
    _checkingClipboard = true;
    try {
      final value =
          (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
      if (!_isWebUrl(value) || value == _lastClipboardUrl || !mounted) return;
      _lastClipboardUrl = value;
      setState(() => _clipboardUrl = value);
      final action = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link found in clipboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 0),
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('Open'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, 1),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || action == null) return;
      if (action == 0) await _tab.controller.loadRequest(Uri.parse(value));
      if (action == 1) await _startDownload(value);
    } on PlatformException {
      // Clipboard may be unavailable temporarily.
    } finally {
      _checkingClipboard = false;
    }
  }

  Future<void> _showTabs() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tabs',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reopen closed tab',
                          onPressed: _closedTabs.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  _reopenClosedTab();
                                },
                          icon: const Icon(Icons.restore_rounded),
                        ),
                        IconButton(
                          tooltip: 'Close all tabs',
                          onPressed: _tabs.length <= 1
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  _closeAllTabs();
                                },
                          icon: const Icon(Icons.delete_sweep_outlined),
                        ),
                        IconButton.filledTonal(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _addTab(_homeUrl);
                          },
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        final item = _tabs[index];
                        return Card(
                          child: ListTile(
                            selected: index == _currentIndex,
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _host(item.url),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              _switchTab(index);
                              Navigator.pop(sheetContext);
                            },
                            trailing: IconButton(
                              onPressed: () {
                                _closeTab(index);
                                refresh(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSaved(
    String title,
    List<String> items, {
    bool history = false,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                trailing: history && items.isNotEmpty
                    ? TextButton(
                        onPressed: () {
                          setState(_history.clear);
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      )
                    : null,
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Nothing here yet'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: Icon(
                            history
                                ? Icons.history_rounded
                                : Icons.bookmark_rounded,
                          ),
                          title: Text(_host(items[i])),
                          subtitle: Text(
                            items[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, items[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await _loadUrl(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmarked = _tab.url != _homeUrl && _bookmarks.contains(_tab.url);
    return Scaffold(
      appBar: _tab.url == _homeUrl
          ? null
          : AppBar(
        titleSpacing: 14,
        title: const Text(
          'Browser',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => _addTab(_homeUrl),
            tooltip: 'New tab',
            icon: const Icon(Icons.add_box_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Badge(
              label: Text('${_tabs.length}'),
              child: IconButton.filledTonal(
                onPressed: _showTabs,
                tooltip: 'Tabs',
                icon: const Icon(Icons.tab_rounded),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tab.url != _homeUrl)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: TextField(
              controller: _addressController,
              focusNode: _addressFocus,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _openAddress(),
              decoration: InputDecoration(
                hintText: 'Search or enter address',
                prefixIcon: Icon(
                  _tab.url.startsWith('https://')
                      ? Icons.lock_outline_rounded
                      : Icons.language_rounded,
                  size: 20,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_tab.loading)
                      IconButton(
                        onPressed: () async {
                          await _tab.controller.runJavaScript('window.stop();');
                          if (!mounted) return;
                          setState(() => _tab.loading = false);
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    else
                      IconButton(
                        onPressed: _tab.controller.reload,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    IconButton(
                      onPressed: _openAddress,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_tab.loading)
            LinearProgressIndicator(
              value: _tab.progress == 0 ? null : _tab.progress / 100,
              minHeight: 2,
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs.map((item) {
                if (item.url == _homeUrl) {
                  return _BrowserStartPage(
                    tabCount: _tabs.length,
                    onSearch: (value) async {
                      _addressController.text = value;
                      await _openAddress();
                    },
                    onOpenSite: _loadUrl,
                    onNewTab: () => _addTab(_homeUrl),
                    onShowTabs: _showTabs,
                    recentUrls: List.unmodifiable(_history.take(6)),
                    mostVisitedUrls: List.unmodifiable(_mostVisitedUrls),
                    clipboardUrl: _clipboardUrl,
                    onOpenClipboard: _clipboardUrl == null
                        ? null
                        : () => _loadUrl(_clipboardUrl!),
                    onDownloadClipboard: _clipboardUrl == null
                        ? null
                        : () => _startDownload(_clipboardUrl!),
                  );
                }
                return WebViewWidget(controller: item.controller);
              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: .2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: _tab.canGoBack ? _tab.controller.goBack : null,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              IconButton(
                onPressed: _tab.canGoForward ? _tab.controller.goForward : null,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              IconButton(
                onPressed: _goHome,
                icon: const Icon(Icons.home_outlined),
              ),
              IconButton(
                onPressed: _tab.url == _homeUrl
                    ? null
                    : () {
                        setState(() {
                          bookmarked
                              ? _bookmarks.remove(_tab.url)
                              : _bookmarks.add(_tab.url);
                        });
                      },
                icon: Icon(
                  bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  if (value == 'download') await _askDownload(_tab.url);
                  if (value == 'copy') {
                    await Clipboard.setData(ClipboardData(text: _tab.url));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  }
                  if (value == 'history') {
                    await _showSaved(
                      'History',
                      List.of(_history),
                      history: true,
                    );
                  }
                  if (value == 'bookmarks') {
                    await _showSaved('Bookmarks', _bookmarks.toList());
                  }
                  if (value == 'share') await Share.share(_tab.url);
                  if (value == 'desktop') await _toggleDesktopMode();
                  if (value == 'find') await _findInPage();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'download',
                    child: ListTile(
                      leading: Icon(Icons.download_rounded),
                      title: Text('Download link'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Copy link'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'bookmarks',
                    child: ListTile(
                      leading: Icon(Icons.bookmarks_outlined),
                      title: Text('Bookmarks'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'history',
                    child: ListTile(
                      leading: Icon(Icons.history_rounded),
                      title: Text('History'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'find',
                    child: ListTile(
                      leading: Icon(Icons.manage_search_rounded),
                      title: Text('Find in page'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'desktop',
                    child: ListTile(
                      leading: Icon(
                        _tab.desktopMode
                            ? Icons.phone_android_rounded
                            : Icons.desktop_windows_rounded,
                      ),
                      title: Text(
                        _tab.desktopMode ? 'Mobile mode' : 'Desktop mode',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share_rounded),
                      title: Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserStartPage extends StatefulWidget {
  const _BrowserStartPage({
    required this.tabCount,
    required this.onSearch,
    required this.onOpenSite,
    required this.onNewTab,
    required this.onShowTabs,
    required this.recentUrls,
    required this.mostVisitedUrls,
    this.clipboardUrl,
    this.onOpenClipboard,
    this.onDownloadClipboard,
  });

  final int tabCount;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onOpenSite;
  final VoidCallback onNewTab;
  final VoidCallback onShowTabs;
  final List<String> recentUrls;
  final List<String> mostVisitedUrls;
  final String? clipboardUrl;
  final VoidCallback? onOpenClipboard;
  final VoidCallback? onDownloadClipboard;

  @override
  State<_BrowserStartPage> createState() => _BrowserStartPageState();
}

class _BrowserStartPageState extends State<_BrowserStartPage> {
  final _searchController = TextEditingController();
  final List<_QuickSite> _sites = <_QuickSite>[
    const _QuickSite(
      'Google',
      'G',
      'https://www.google.com',
      Color(0xFF4285F4),
    ),
    const _QuickSite(
      'YouTube',
      '▶',
      'https://www.youtube.com',
      Color(0xFFFF1744),
    ),
    const _QuickSite(
      'Facebook',
      'f',
      'https://www.facebook.com',
      Color(0xFF1877F2),
    ),
    const _QuickSite(
      'Instagram',
      '◎',
      'https://www.instagram.com',
      Color(0xFFE1306C),
    ),
    const _QuickSite(
      'TikTok',
      '♪',
      'https://www.tiktok.com',
      Color(0xFF111111),
    ),
    const _QuickSite('X', 'X', 'https://x.com', Color(0xFF111111)),
    const _QuickSite(
      'Wikipedia',
      'W',
      'https://www.wikipedia.org',
      Color(0xFF5F6368),
    ),
    const _QuickSite('Reddit', 'r', 'https://www.reddit.com', Color(0xFFFF4500)),
    const _QuickSite('Medium', 'M', 'https://medium.com', Color(0xFF202124)),
    const _QuickSite('Twitch', 'T', 'https://www.twitch.tv', Color(0xFF9146FF)),
    const _QuickSite('Airbnb', 'A', 'https://www.airbnb.com', Color(0xFFFF5A5F)),
    const _QuickSite('Netflix', 'N', 'https://www.netflix.com', Color(0xFFE50914)),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _searchController.text.trim();
    if (value.isNotEmpty) widget.onSearch(value);
  }

  Future<void> _addShortcut() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final result = await showDialog<_QuickSite>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.add_link_rounded),
        title: const Text('Add shortcut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website address',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.language_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              var url = urlController.text.trim();
              if (name.isEmpty || url.isEmpty) return;
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'https://$url';
              }
              final uri = Uri.tryParse(url);
              if (uri == null || uri.host.isEmpty) return;
              Navigator.pop(
                dialogContext,
                _QuickSite(
                  name,
                  name.substring(0, 1).toUpperCase(),
                  url,
                  const Color(0xFF7C4DFF),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    urlController.dispose();
    if (!mounted || result == null) return;
    setState(() => _sites.add(result));
  }

  Future<void> _editShortcut(int index) async {
    final site = _sites[index];
    final nameController = TextEditingController(text: site.name);
    final urlController = TextEditingController(text: site.url);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit shortcut', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: urlController, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Website address')),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'delete'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'save'),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      setState(() => _sites.removeAt(index));
    } else if (action == 'save') {
      final name = nameController.text.trim();
      var url = urlController.text.trim();
      if (name.isEmpty || url.isEmpty) return;
      if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'https://$url';
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) return;
      setState(() {
        _sites[index] = _QuickSite(name, name.substring(0, 1).toUpperCase(), url, site.color);
      });
    }
    nameController.dispose();
    urlController.dispose();
  }

  void _moveSite(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= _sites.length || to >= _sites.length) return;
    setState(() {
      final site = _sites.removeAt(from);
      _sites.insert(to, site);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF17121F), Color(0xFF0F0D14)]
              : const [Color(0xFFF8F4FF), Color(0xFFF2ECFF)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                _RoundAction(
                  icon: Icons.add_rounded,
                  tooltip: 'New tab',
                  onTap: widget.onNewTab,
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.onShowTabs,
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: .55),
                      ),
                    ),
                    child: Text(
                      '${widget.tabCount}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8257FF), Color(0xFFB86BFF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3D7C4DFF),
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Filexa Browser',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Fast. Simple. Yours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: .12),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Search or enter address',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton.filled(
                    onPressed: _submit,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ),
            if (widget.clipboardUrl != null) ...[
              const SizedBox(height: 14),
              _ClipboardLinkCard(
                url: widget.clipboardUrl!,
                onOpen: widget.onOpenClipboard!,
                onDownload: widget.onDownloadClipboard!,
              ),
            ],
            AnimatedBuilder(
              animation: DownloadManager.instance,
              builder: (context, _) {
                final active = DownloadManager.instance.tasks
                    .where((task) => task.isActive)
                    .toList();
                final speed = active.fold<double>(
                  0,
                  (sum, task) => sum + task.speedBytesPerSecond,
                );
                if (active.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _BrowserStatusCard(
                    activeCount: active.length,
                    speedBytesPerSecond: speed,
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Top sites',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addShortcut,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 18,
                crossAxisSpacing: 12,
                childAspectRatio: .72,
              ),
              itemCount: _sites.length + 1,
              itemBuilder: (context, index) {
                if (index == _sites.length) {
                  return _AddSiteTile(onTap: _addShortcut);
                }
                final site = _sites[index];
                return _SiteTile(
                  site: site,
                  index: index,
                  onTap: () => widget.onOpenSite(site.url),
                  onEdit: () => _editShortcut(index),
                  onMove: _moveSite,
                );
              },
            ),
            if (widget.recentUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Recently visited', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.recentUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final url = widget.recentUrls[index];
                    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
                    return ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 18),
                      label: SizedBox(width: 110, child: Text(host, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      onPressed: () => widget.onOpenSite(url),
                    );
                  },
                ),
              ),
            ],
            if (widget.mostVisitedUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Most visited',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Icon(Icons.local_fire_department_rounded),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.mostVisitedUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final url = widget.mostVisitedUrls[index];
                    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
                    return ActionChip(
                      avatar: const Icon(Icons.trending_up_rounded, size: 18),
                      label: Text(host),
                      onPressed: () => widget.onOpenSite(url),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Discover',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                Icon(Icons.auto_awesome_rounded, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            _DiscoverCard(
              icon: Icons.folder_copy_rounded,
              title: 'Browse. Download. Organize.',
              subtitle: 'Open direct links, manage active downloads, and find every saved file in File Hub.',
              colors: const [Color(0xFF180A3D), Color(0xFF4C1D95), Color(0xFF7C3AED)],
              onTap: () {},
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniDiscoverCard(
                    icon: Icons.download_for_offline_rounded,
                    title: 'Direct downloads',
                    color: const Color(0xFF536DFE),
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniDiscoverCard(
                    icon: Icons.bolt_rounded,
                    title: 'File Hub ready',
                    color: const Color(0xFFEC407A),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon),
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.site,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onMove,
  });

  final _QuickSite site;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final void Function(int from, int to) onMove;

  @override
  Widget build(BuildContext context) {
    final tile = InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      onLongPress: onEdit,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: site.color,
              borderRadius: BorderRadius.circular(19),
              boxShadow: [
                BoxShadow(
                  color: site.color.withValues(alpha: .24),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Text(
              site.symbol,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            site.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => onMove(details.data, index),
      builder: (context, candidates, rejected) => LongPressDraggable<int>(
        data: index,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 82, height: 100, child: tile),
        ),
        childWhenDragging: Opacity(opacity: .28, child: tile),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: candidates.isEmpty ? 1 : 1.06,
          child: tile,
        ),
      ),
    );
  }
}

class _AddSiteTile extends StatelessWidget {
  const _AddSiteTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: .88),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: scheme.primary.withValues(alpha: .3),
              ),
            ),
            child: Icon(Icons.add_rounded, color: scheme.primary, size: 28),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ClipboardLinkCard extends StatelessWidget {
  const _ClipboardLinkCard({required this.url, required this.onOpen, required this.onDownload});

  final String url;
  final VoidCallback onOpen;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.content_paste_go_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clipboard link ready', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(onPressed: onOpen, tooltip: 'Open', icon: const Icon(Icons.open_in_browser_rounded)),
          IconButton.filled(onPressed: onDownload, tooltip: 'Download', icon: const Icon(Icons.download_rounded)),
        ],
      ),
    );
  }
}

class _BrowserStatusCard extends StatelessWidget {
  const _BrowserStatusCard({
    required this.activeCount,
    required this.speedBytesPerSecond,
  });

  final int activeCount;
  final double speedBytesPerSecond;

  String _formatSpeed(double value) {
    if (value < 1024) return '${value.toStringAsFixed(0)} B/s';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB/s';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B35C8), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D4AFF).withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.downloading_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$activeCount active download${activeCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatSpeed(speedBytesPerSecond),
                  style: TextStyle(color: Colors.white.withValues(alpha: .78)),
                ),
              ],
            ),
          ),
          const Icon(Icons.bolt_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: .28), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: .42),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .94),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _MiniDiscoverCard extends StatelessWidget {
  const _MiniDiscoverCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSite {
  const _QuickSite(this.name, this.symbol, this.url, this.color);

  final String name;
  final String symbol;
  final String url;
  final Color color;
}
