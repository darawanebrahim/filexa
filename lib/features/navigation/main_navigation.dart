import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../core/download_manager.dart';
import '../../core/providers/file_provider.dart';
import '../../shared/new_download_dialog.dart';
import '../browser/browser_page.dart';
import '../downloads/downloads_page.dart';
import '../files/files_page.dart';
import '../home/home_page.dart';
import '../settings/settings_page.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _clipboardTimer;
  String? _lastClipboardText;
  bool _promptVisible = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  static const List<Widget> _pages = [
    HomePage(),
    FilesPage(),
    BrowserPage(),
    DownloadsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppController.clipboardDetection.addListener(_handleClipboardSetting);
    _handleClipboardSetting();
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    AppController.clipboardDetection.removeListener(_handleClipboardSetting);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _startClipboardWatcher();
      unawaited(_checkClipboard());
    } else {
      _clipboardTimer?.cancel();
      _clipboardTimer = null;
    }
  }

  void _handleClipboardSetting() {
    if (AppController.clipboardDetection.value) {
      _startClipboardWatcher();
    } else {
      _clipboardTimer?.cancel();
      _clipboardTimer = null;
    }
  }

  void _startClipboardWatcher() {
    if (!AppController.clipboardDetection.value ||
        _lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _clipboardTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_checkClipboard()),
    );
  }

  Future<void> _checkClipboard() async {
    if (!mounted ||
        _promptVisible ||
        !AppController.clipboardDetection.value ||
        _lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || text == _lastClipboardText || !_isDownloadableUrl(text)) {
      return;
    }

    _lastClipboardText = text;
    _promptVisible = true;
    try {
      await _showClipboardPrompt(text);
    } finally {
      _promptVisible = false;
    }
  }

  Future<void> _showClipboardPrompt(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !mounted) return;
    final fileName = _suggestFileName(uri);
    final shouldDownload = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.content_paste_go_rounded,
                    color: Theme.of(sheetContext).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download detected',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text('Do you want to download this copied file?'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    uri.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (shouldDownload != true || !mounted) return;
    final request = await showNewDownloadDialog(
      context,
      initialUrl: url,
      initialFileName: fileName,
    );
    if (request == null || !mounted) return;
    await DownloadManager.instance.startDownload(
      url: request.url,
      fileName: request.fileName,
      folder: request.folder,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Downloading ${request.fileName}…')),
      );
  }

  static bool _isDownloadableUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return false;
    }
    final path = uri.path.toLowerCase();
    return RegExp(
      r'\.(pdf|zip|rar|7z|apk|iso|docx?|xlsx?|pptx?|mp3|m4a|wav|flac|mp4|mkv|webm|avi|mov|jpg|jpeg|png|gif|webp|html?|css|js|json|xml|php|md|txt|csv|srt|vtt)$',
    ).hasMatch(path);
  }

  static String _suggestFileName(Uri uri) {
    if (uri.pathSegments.isNotEmpty) {
      final candidate = Uri.decodeComponent(uri.pathSegments.last).trim();
      if (candidate.isNotEmpty) return candidate;
    }
    final host = uri.host.replaceFirst('www.', '').split('.').first;
    return '${host.isEmpty ? 'download' : host}_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: .65),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                if (index == 1) ref.invalidate(filesProvider);
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder_rounded),
                  label: 'Files',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public_rounded),
                  label: 'Browser',
                ),
                NavigationDestination(
                  icon: Icon(Icons.download_outlined),
                  selectedIcon: Icon(Icons.download_rounded),
                  label: 'Downloads',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
