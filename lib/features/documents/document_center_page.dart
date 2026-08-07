import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_item.dart';
import '../../core/providers/file_provider.dart';
import '../../theme/filexa_ui.dart';
import 'text_document_viewer.dart';
import 'office_studio_page.dart';

enum _DocumentType { all, pdf, word, spreadsheet, presentation, text }
enum _DocumentSort { newest, oldest, name, largest }

class DocumentCenterPage extends ConsumerStatefulWidget {
  const DocumentCenterPage({super.key});

  @override
  ConsumerState<DocumentCenterPage> createState() => _DocumentCenterPageState();
}

class _DocumentCenterPageState extends ConsumerState<DocumentCenterPage> {
  final _searchController = TextEditingController();
  _DocumentType _type = _DocumentType.all;
  _DocumentSort _sort = _DocumentSort.newest;
  bool _gridView = false;
  final Set<String> _favorites = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(filesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Center'),
        actions: [
          IconButton(
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
            icon: Icon(_gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
          PopupMenuButton<_DocumentSort>(
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _DocumentSort.newest, child: Text('Newest first')),
              PopupMenuItem(value: _DocumentSort.oldest, child: Text('Oldest first')),
              PopupMenuItem(value: _DocumentSort.name, child: Text('Name')),
              PopupMenuItem(value: _DocumentSort.largest, child: Text('Largest first')),
            ],
          ),
        ],
      ),
      body: files.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => FilexaEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Documents could not be loaded',
          message: '$error',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(filesProvider),
        ),
        data: (allFiles) {
          final documents = _filteredDocuments(allFiles);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(filesProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: FilexaPageHeader(
                    title: 'PDF & Documents',
                    subtitle: '${_documentFiles(allFiles).length} files ready to read and share',
                    icon: Icons.description_rounded,
                    trailing: IconButton.filledTonal(
                      tooltip: 'Refresh',
                      onPressed: () => ref.invalidate(filesProvider),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildSearchAndFilters(context)),
                if (documents.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: FilexaEmptyState(
                      icon: Icons.folder_off_outlined,
                      title: _searchController.text.trim().isEmpty
                          ? 'No documents yet'
                          : 'No matching documents',
                      message: _searchController.text.trim().isEmpty
                          ? 'PDF, Word, Excel, PowerPoint and text files will appear here.'
                          : 'Try another search or document filter.',
                    ),
                  )
                else if (_gridView)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 184,
                      ),
                      itemCount: documents.length,
                      itemBuilder: (context, index) => _DocumentGridCard(
                        item: documents[index],
                        favorite: _favorites.contains(documents[index].path),
                        onOpen: () => _openDocument(documents[index]),
                        onMenu: () => _showActions(documents[index]),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                    sliver: SliverList.separated(
                      itemCount: documents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = documents[index];
                        return _DocumentListCard(
                          item: item,
                          favorite: _favorites.contains(item.path),
                          onOpen: () => _openDocument(item),
                          onFavorite: () => _toggleFavorite(item),
                          onMenu: () => _showActions(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search documents',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _DocumentType.values.map((type) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                    avatar: Icon(_typeIcon(type), size: 18),
                    label: Text(_typeLabel(type)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<FileItem> _documentFiles(List<FileItem> files) =>
      files.where((item) => _documentTypeFor(item.name) != null).toList();

  List<FileItem> _filteredDocuments(List<FileItem> files) {
    final query = _searchController.text.trim().toLowerCase();
    final results = _documentFiles(files).where((item) {
      final type = _documentTypeFor(item.name)!;
      final matchesType = _type == _DocumentType.all || _type == type;
      final matchesQuery = query.isEmpty || item.name.toLowerCase().contains(query);
      return matchesType && matchesQuery;
    }).toList();

    results.sort((a, b) {
      switch (_sort) {
        case _DocumentSort.newest:
          return b.modified.compareTo(a.modified);
        case _DocumentSort.oldest:
          return a.modified.compareTo(b.modified);
        case _DocumentSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _DocumentSort.largest:
          return b.size.compareTo(a.size);
      }
    });
    return results;
  }

  Future<void> _openDocument(FileItem item) async {
    final extension = p.extension(item.name).toLowerCase();
    if (extension == '.txt' || extension == '.md' || extension == '.json' || extension == '.csv') {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TextDocumentViewer(item: item)),
      );
      return;
    }
    if (const {'.docx', '.xlsx', '.pptx'}.contains(extension)) {
      if (!mounted) return;
      await openOfficeFile(context, item);
      return;
    }

    final result = await OpenFilex.open(item.path);
    if (!mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message.isEmpty ? 'No compatible viewer was found.' : result.message)),
    );
  }

  void _toggleFavorite(FileItem item) {
    setState(() {
      if (!_favorites.add(item.path)) _favorites.remove(item.path);
    });
  }

  Future<void> _showActions(FileItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _DocumentIcon(name: item.name),
                title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${_formatBytes(item.size)} • ${_typeLabel(_documentTypeFor(item.name)!)}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openDocument(item);
                },
              ),
              ListTile(
                leading: Icon(_favorites.contains(item.path) ? Icons.star_rounded : Icons.star_outline_rounded),
                title: Text(_favorites.contains(item.path) ? 'Remove from favorites' : 'Add to favorites'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleFavorite(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  SharePlus.instance.share(
                    ShareParams(files: [XFile(item.path)], subject: item.name),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Details'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDetails(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(FileItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Name', value: item.name),
            _DetailRow(label: 'Type', value: _typeLabel(_documentTypeFor(item.name)!)),
            _DetailRow(label: 'Size', value: _formatBytes(item.size)),
            _DetailRow(label: 'Modified', value: item.modified.toLocal().toString().split('.').first),
            _DetailRow(label: 'Location', value: item.path),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _DocumentListCard extends StatelessWidget {
  const _DocumentListCard({
    required this.item,
    required this.favorite,
    required this.onOpen,
    required this.onFavorite,
    required this.onMenu,
  });

  final FileItem item;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FilexaUi.surface(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: FilexaUi.cardDecoration(context, radius: 20, elevated: false),
          child: Row(
            children: [
              _DocumentIcon(name: item.name),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatBytes(item.size)} • ${_formatDate(item.modified)}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onFavorite, icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded)),
              IconButton(onPressed: onMenu, icon: const Icon(Icons.more_vert_rounded)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentGridCard extends StatelessWidget {
  const _DocumentGridCard({required this.item, required this.favorite, required this.onOpen, required this.onMenu});
  final FileItem item;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FilexaUi.surface(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: FilexaUi.cardDecoration(context, radius: 22, elevated: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DocumentIcon(name: item.name),
                  const Spacer(),
                  if (favorite) const Icon(Icons.star_rounded, size: 20, color: Colors.amber),
                  IconButton(onPressed: onMenu, icon: const Icon(Icons.more_vert_rounded), visualDensity: VisualDensity.compact),
                ],
              ),
              const Spacer(),
              Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_formatBytes(item.size), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentIcon extends StatelessWidget {
  const _DocumentIcon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final type = _documentTypeFor(name) ?? _DocumentType.text;
    final color = _typeColor(type);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(15)),
      child: Icon(_typeIcon(type), color: color),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

_DocumentType? _documentTypeFor(String name) {
  switch (p.extension(name).toLowerCase()) {
    case '.pdf': return _DocumentType.pdf;
    case '.doc':
    case '.docx':
    case '.odt': return _DocumentType.word;
    case '.xls':
    case '.xlsx':
    case '.ods':
    case '.csv': return _DocumentType.spreadsheet;
    case '.ppt':
    case '.pptx':
    case '.odp': return _DocumentType.presentation;
    case '.txt':
    case '.md':
    case '.json': return _DocumentType.text;
    default: return null;
  }
}

String _typeLabel(_DocumentType type) => switch (type) {
  _DocumentType.all => 'All',
  _DocumentType.pdf => 'PDF',
  _DocumentType.word => 'Word',
  _DocumentType.spreadsheet => 'Sheets',
  _DocumentType.presentation => 'Slides',
  _DocumentType.text => 'Text',
};

IconData _typeIcon(_DocumentType type) => switch (type) {
  _DocumentType.all => Icons.dashboard_rounded,
  _DocumentType.pdf => Icons.picture_as_pdf_rounded,
  _DocumentType.word => Icons.article_rounded,
  _DocumentType.spreadsheet => Icons.table_chart_rounded,
  _DocumentType.presentation => Icons.slideshow_rounded,
  _DocumentType.text => Icons.text_snippet_rounded,
};

Color _typeColor(_DocumentType type) => switch (type) {
  _DocumentType.all => FilexaUi.primary,
  _DocumentType.pdf => const Color(0xFFEF4444),
  _DocumentType.word => const Color(0xFF3B82F6),
  _DocumentType.spreadsheet => const Color(0xFF10B981),
  _DocumentType.presentation => const Color(0xFFF97316),
  _DocumentType.text => const Color(0xFF8B5CF6),
};

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
