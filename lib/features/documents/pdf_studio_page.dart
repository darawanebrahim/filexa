import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_item.dart';
import '../../core/providers/file_metadata_provider.dart';
import '../../core/providers/file_provider.dart';
import '../../theme/filexa_ui.dart';

enum _PdfSort { newest, oldest, name, largest }
enum _PdfView { all, favorites }

class PdfStudioPage extends ConsumerStatefulWidget {
  const PdfStudioPage({super.key});

  @override
  ConsumerState<PdfStudioPage> createState() => _PdfStudioPageState();
}

class _PdfStudioPageState extends ConsumerState<PdfStudioPage> {
  final TextEditingController _searchController = TextEditingController();
  _PdfSort _sort = _PdfSort.newest;
  _PdfView _view = _PdfView.all;
  bool _gridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(filesProvider);
    final metadata = ref.watch(fileMetadataProvider).valueOrNull;
    final favorites = metadata?.favoritePaths ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Studio'),
        actions: [
          IconButton(
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
            icon: Icon(_gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
          PopupMenuButton<_PdfSort>(
            tooltip: 'Sort PDFs',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _PdfSort.newest, child: Text('Newest first')),
              PopupMenuItem(value: _PdfSort.oldest, child: Text('Oldest first')),
              PopupMenuItem(value: _PdfSort.name, child: Text('Name')),
              PopupMenuItem(value: _PdfSort.largest, child: Text('Largest first')),
            ],
          ),
        ],
      ),
      body: files.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => FilexaEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'PDF Studio could not load files',
          message: '$error',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(filesProvider),
        ),
        data: (allFiles) {
          final allPdfs = allFiles.where(_isPdf).toList(growable: false);
          final visible = _filtered(allPdfs, favorites);
          final totalBytes = allPdfs.fold<int>(0, (sum, item) => sum + item.size);
          final favoriteCount = allPdfs.where((item) => favorites.contains(item.path)).length;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(filesProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _PdfHero(
                    count: allPdfs.length,
                    favoriteCount: favoriteCount,
                    totalBytes: totalBytes,
                    onRefresh: () => ref.invalidate(filesProvider),
                  ),
                ),
                SliverToBoxAdapter(child: _buildSearchAndFilter()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your PDFs',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${visible.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: FilexaEmptyState(
                      icon: Icons.picture_as_pdf_outlined,
                      title: _searchController.text.trim().isEmpty
                          ? (_view == _PdfView.favorites ? 'No favorite PDFs' : 'No PDF files yet')
                          : 'No matching PDF',
                      message: _searchController.text.trim().isEmpty
                          ? 'PDF files discovered by Filexa will appear here.'
                          : 'Try another file name or clear the filter.',
                    ),
                  )
                else if (_gridView)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                    sliver: SliverGrid.builder(
                      itemCount: visible.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 194,
                      ),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return _PdfGridCard(
                          item: item,
                          favorite: favorites.contains(item.path),
                          onOpen: () => _open(item),
                          onActions: () => _showActions(item, favorites.contains(item.path)),
                        );
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return _PdfListCard(
                          item: item,
                          favorite: favorites.contains(item.path),
                          onOpen: () => _open(item),
                          onFavorite: () => _toggleFavorite(item),
                          onActions: () => _showActions(item, favorites.contains(item.path)),
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

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search PDF files',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_PdfView>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _PdfView.all,
                      icon: Icon(Icons.picture_as_pdf_rounded),
                      label: Text('All PDFs'),
                    ),
                    ButtonSegment(
                      value: _PdfView.favorites,
                      icon: Icon(Icons.star_rounded),
                      label: Text('Favorites'),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) => setState(() => _view = selection.first),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<FileItem> _filtered(List<FileItem> files, Set<String> favorites) {
    final query = _searchController.text.trim().toLowerCase();
    final result = files.where((item) {
      if (_view == _PdfView.favorites && !favorites.contains(item.path)) return false;
      return query.isEmpty || item.name.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      switch (_sort) {
        case _PdfSort.newest:
          return b.modified.compareTo(a.modified);
        case _PdfSort.oldest:
          return a.modified.compareTo(b.modified);
        case _PdfSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _PdfSort.largest:
          return b.size.compareTo(a.size);
      }
    });
    return result;
  }

  Future<void> _open(FileItem item) async {
    final result = await OpenFilex.open(item.path);
    if (!mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message.isEmpty ? 'No PDF viewer was found.' : result.message)),
    );
  }

  Future<void> _toggleFavorite(FileItem item) async {
    await ref.read(fileMetadataProvider.notifier).toggleFavorite(item.path);
  }

  Future<void> _showActions(FileItem item, bool favorite) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.picture_as_pdf_rounded),
                ),
                title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${_formatBytes(item.size)} • ${_formatDate(item.modified)}'),
              ),
              const Divider(),
              _SheetAction(
                icon: Icons.menu_book_rounded,
                title: 'Read PDF',
                subtitle: 'Open with the best PDF viewer available on this device',
                onTap: () => Navigator.pop(sheetContext, 'open'),
              ),
              _SheetAction(
                icon: favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                title: favorite ? 'Remove from favorites' : 'Add to favorites',
                subtitle: 'Keep important PDFs easy to find',
                onTap: () => Navigator.pop(sheetContext, 'favorite'),
              ),
              _SheetAction(
                icon: Icons.share_rounded,
                title: 'Share PDF',
                subtitle: 'Send the original PDF to another app',
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
              _SheetAction(
                icon: Icons.content_copy_rounded,
                title: 'Copy file location',
                subtitle: item.path,
                onTap: () => Navigator.pop(sheetContext, 'copy_path'),
              ),
              _SheetAction(
                icon: Icons.info_outline_rounded,
                title: 'PDF information',
                subtitle: 'Size, modified date and storage location',
                onTap: () => Navigator.pop(sheetContext, 'info'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _open(item);
      case 'favorite':
        await _toggleFavorite(item);
      case 'share':
        await SharePlus.instance.share(
          ShareParams(files: [XFile(item.path)], subject: item.name),
        );
      case 'copy_path':
        await Clipboard.setData(ClipboardData(text: item.path));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF location copied')),
        );
      case 'info':
        await _showInfo(item);
    }
  }

  Future<void> _showInfo(FileItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PDF information', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              _InfoRow(label: 'Name', value: item.name),
              _InfoRow(label: 'Size', value: _formatBytes(item.size)),
              _InfoRow(label: 'Modified', value: _formatDate(item.modified)),
              _InfoRow(label: 'Location', value: item.path),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfHero extends StatelessWidget {
  const _PdfHero({
    required this.count,
    required this.favoriteCount,
    required this.totalBytes,
    required this.onRefresh,
  });

  final int count;
  final int favoriteCount;
  final int totalBytes;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: .22),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 31),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF Studio',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'One place for your PDF workspace',
                        style: TextStyle(color: Color(0xFFEDE9FE), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh PDFs',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _HeroMetric(value: '$count', label: 'PDF files')),
                const SizedBox(width: 10),
                Expanded(child: _HeroMetric(value: '$favoriteCount', label: 'Favorites')),
                const SizedBox(width: 10),
                Expanded(child: _HeroMetric(value: _formatBytes(totalBytes), label: 'Managed')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFEDE9FE), fontSize: 11)),
        ],
      ),
    );
  }
}

class _PdfListCard extends StatelessWidget {
  const _PdfListCard({
    required this.item,
    required this.favorite,
    required this.onOpen,
    required this.onFavorite,
    required this.onActions,
  });

  final FileItem item;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FilexaUi.cardDecoration(context, radius: 22, elevated: false),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444)),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${_formatBytes(item.size)} • ${_formatDate(item.modified)}'),
        onTap: onOpen,
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: favorite ? 'Remove favorite' : 'Favorite',
              onPressed: onFavorite,
              icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded),
            ),
            IconButton(
              tooltip: 'PDF actions',
              onPressed: onActions,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfGridCard extends StatelessWidget {
  const _PdfGridCard({required this.item, required this.favorite, required this.onOpen, required this.onActions});
  final FileItem item;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FilexaUi.cardDecoration(context, radius: 24, elevated: false),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444)),
                    ),
                    const Spacer(),
                    if (favorite) const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                    IconButton(onPressed: onActions, icon: const Icon(Icons.more_vert_rounded)),
                  ],
                ),
                const Spacer(),
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, height: 1.12)),
                const SizedBox(height: 7),
                Text(_formatBytes(item.size), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(_formatDate(item.modified), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 82, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(child: SelectableText(value)),
          ],
        ),
      );
}

bool _isPdf(FileItem item) => item.name.toLowerCase().endsWith('.pdf');

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
