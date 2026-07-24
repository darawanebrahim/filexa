import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/models/file_item.dart';
import '../../core/providers/file_provider.dart';
import '../../theme/filexa_ui.dart';

enum _SearchType { all, documents, media, archives, apps }
enum _SearchSort { relevance, newest, largest, name }

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});
  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _controller = TextEditingController();
  final List<String> _recentSearches = <String>[];
  String _query = '';
  _SearchType _type = _SearchType.all;
  _SearchSort _sort = _SearchSort.relevance;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(filesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Search everything')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: _rememberSearch,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'File name, type or extension',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? IconButton(onPressed: _showFilters, icon: const Icon(Icons.tune_rounded))
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: _SearchType.values.map((type) {
                  final selected = _type == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(_typeLabel(type)),
                      onSelected: (_) => setState(() => _type = type),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: filesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => FilexaEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Search is unavailable',
                  message: error.toString(),
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(filesProvider),
                ),
                data: (files) {
                  if (_query.isEmpty) return _SearchStart(recent: _recentSearches, onTap: _applyRecent);
                  final results = _results(files);
                  if (results.isEmpty) {
                    return const FilexaEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No results',
                      message: 'Try another name, extension or file category.',
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                        child: Row(
                          children: [
                            Expanded(child: Text('${results.length} results', style: const TextStyle(fontWeight: FontWeight.w800))),
                            TextButton.icon(onPressed: _showFilters, icon: const Icon(Icons.sort_rounded), label: Text(_sortLabel(_sort))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _ResultTile(
                            item: results[index],
                            query: _query,
                            onTap: () => OpenFilex.open(results[index].path),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FileItem> _results(List<FileItem> files) {
    final query = _query.toLowerCase();
    final results = files.where((file) {
      final text = '${file.name} ${p.extension(file.name)}'.toLowerCase();
      return text.contains(query) && _matchesType(file.name, _type);
    }).toList();
    results.sort((a, b) {
      switch (_sort) {
        case _SearchSort.relevance:
          final aStarts = a.name.toLowerCase().startsWith(query) ? 0 : 1;
          final bStarts = b.name.toLowerCase().startsWith(query) ? 0 : 1;
          return aStarts != bStarts ? aStarts.compareTo(bStarts) : b.modified.compareTo(a.modified);
        case _SearchSort.newest:
          return b.modified.compareTo(a.modified);
        case _SearchSort.largest:
          return b.size.compareTo(a.size);
        case _SearchSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return results;
  }

  void _rememberSearch(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    setState(() {
      _recentSearches.remove(text);
      _recentSearches.insert(0, text);
      if (_recentSearches.length > 5) _recentSearches.removeLast();
    });
  }

  void _applyRecent(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value);
  }

  Future<void> _showFilters() async {
    var type = _type;
    var sort = _sort;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Search filters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                const Text('File type', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _SearchType.values.map((value) => ChoiceChip(
                    selected: type == value,
                    label: Text(_typeLabel(value)),
                    onSelected: (_) => setSheetState(() => type = value),
                  )).toList(),
                ),
                const SizedBox(height: 18),
                const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w800)),
                ..._SearchSort.values.map(
                  (value) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_sortLabel(value)),
                    trailing: Icon(
                      sort == value
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                    ),
                    onTap: () => setSheetState(() => sort = value),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply filters'))),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied == true) setState(() { _type = type; _sort = sort; });
  }
}

class _SearchStart extends StatelessWidget {
  const _SearchStart({required this.recent, required this.onTap});
  final List<String> recent;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return const FilexaEmptyState(
        icon: Icons.manage_search_rounded,
        title: 'Find anything instantly',
        message: 'Search by file name, extension or category.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
      children: [
        const FilexaSectionTitle(title: 'Recent searches'),
        const SizedBox(height: 10),
        ...recent.map((item) => ListTile(
          leading: const Icon(Icons.history_rounded),
          title: Text(item),
          trailing: const Icon(Icons.north_west_rounded, size: 18),
          onTap: () => onTap(item),
        )),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, required this.query, required this.onTap});
  final FileItem item;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FilexaUi.surface(context),
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: FilexaUi.softSurface(context), borderRadius: BorderRadius.circular(15)),
          child: Icon(_iconFor(item.name), color: FilexaUi.primary),
        ),
        title: _HighlightedText(text: item.name, query: query),
        subtitle: Text('${_formatBytes(item.size)} • ${p.extension(item.name).replaceFirst('.', '').toUpperCase()}'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.query});
  final String text;
  final String query;
  @override
  Widget build(BuildContext context) {
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0 || query.isEmpty) return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800));
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontWeight: FontWeight.w800),
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(text: text.substring(index, index + query.length), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }
}

bool _matchesType(String name, _SearchType type) {
  if (type == _SearchType.all) return true;
  final ext = p.extension(name).toLowerCase();
  switch (type) {
    case _SearchType.all:
      return true;
    case _SearchType.documents:
      return {'.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.epub'}.contains(ext);
    case _SearchType.media:
      return {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.mp4', '.mkv', '.mov', '.avi', '.mp3', '.wav', '.m4a', '.aac'}.contains(ext);
    case _SearchType.archives:
      return {'.zip', '.rar', '.7z', '.tar', '.gz', '.iso'}.contains(ext);
    case _SearchType.apps:
      return ext == '.apk';
  }
}

String _typeLabel(_SearchType type) {
  switch (type) {
    case _SearchType.all: return 'All';
    case _SearchType.documents: return 'Documents';
    case _SearchType.media: return 'Media';
    case _SearchType.archives: return 'Archives';
    case _SearchType.apps: return 'Apps';
  }
}

String _sortLabel(_SearchSort sort) {
  switch (sort) {
    case _SearchSort.relevance: return 'Relevance';
    case _SearchSort.newest: return 'Newest';
    case _SearchSort.largest: return 'Largest';
    case _SearchSort.name: return 'Name';
  }
}

IconData _iconFor(String name) {
  final ext = p.extension(name).toLowerCase();
  if ({'.jpg', '.jpeg', '.png', '.gif', '.webp'}.contains(ext)) return Icons.image_rounded;
  if ({'.mp4', '.mkv', '.mov', '.avi'}.contains(ext)) return Icons.movie_rounded;
  if ({'.mp3', '.wav', '.m4a', '.aac'}.contains(ext)) return Icons.audio_file_rounded;
  if (ext == '.pdf') return Icons.picture_as_pdf_rounded;
  if ({'.zip', '.rar', '.7z', '.iso'}.contains(ext)) return Icons.folder_zip_rounded;
  if (ext == '.apk') return Icons.android_rounded;
  return Icons.insert_drive_file_rounded;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
