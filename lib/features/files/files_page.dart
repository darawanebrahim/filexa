import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_item.dart';
import '../../core/providers/file_provider.dart';
import '../../core/providers/file_metadata_provider.dart';
import '../../core/services/file_metadata_service.dart';
import '../../theme/filexa_ui.dart';
import 'file_explorer_page.dart';

enum _FileCategory { all, favorites, images, videos, audio, documents, archives, apps }
enum _FileSort { newest, oldest, name, size }

class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  final Set<String> _selectedPaths = <String>{};
  String _query = '';
  bool _showSearch = false;
  bool _gridView = false;
  _FileCategory _category = _FileCategory.all;
  _FileSort _sort = _FileSort.newest;

  bool get _selectionMode => _selectedPaths.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(filesProvider);
    final metadata = ref.watch(fileMetadataProvider).valueOrNull ?? const FileMetadata();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: _selectionMode
            ? IconButton(
                onPressed: () => setState(_selectedPaths.clear),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: _selectionMode
            ? Text('${_selectedPaths.length} selected')
            : _showSearch
                ? TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search files',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  )
                : const Text('Files', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: 'Select all visible',
                  onPressed: () {
                    final files = _filteredAndSorted(filesAsync.valueOrNull ?? const <FileItem>[], metadata.favoritePaths);
                    setState(() => _selectedPaths.addAll(files.map((item) => item.path)));
                  },
                  icon: const Icon(Icons.select_all_rounded),
                ),
                IconButton(
                  tooltip: 'Share selected',
                  onPressed: () => _shareSelected(filesAsync.valueOrNull ?? const []),
                  icon: const Icon(Icons.share_rounded),
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  onPressed: () => _deleteSelected(filesAsync.valueOrNull ?? const []),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                const SizedBox(width: 6),
              ]
            : [
                IconButton(
                  tooltip: 'File Explorer Pro',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FileExplorerPage(fileService: ref.read(fileServiceProvider)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_tree_rounded),
                ),
                IconButton(
                  tooltip: _showSearch ? 'Close search' : 'Search',
                  onPressed: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _query = '';
                  }),
                  icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
                ),
                PopupMenuButton<_FileSort>(
                  tooltip: 'Sort files',
                  initialValue: _sort,
                  onSelected: (value) => setState(() => _sort = value),
                  icon: const Icon(Icons.sort_rounded),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: _FileSort.newest, child: Text('Newest first')),
                    PopupMenuItem(value: _FileSort.oldest, child: Text('Oldest first')),
                    PopupMenuItem(value: _FileSort.name, child: Text('Name')),
                    PopupMenuItem(value: _FileSort.size, child: Text('Largest first')),
                  ],
                ),
                IconButton(
                  tooltip: _gridView ? 'List view' : 'Grid view',
                  onPressed: () => setState(() => _gridView = !_gridView),
                  icon: Icon(_gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                ),
                const SizedBox(width: 6),
              ],
      ),
      body: SafeArea(
        child: filesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(filesProvider),
          ),
          data: (files) {
            final visibleFiles = _filteredAndSorted(files, metadata.favoritePaths);
            if (files.isEmpty) {
              return _EmptyFiles(onRefresh: () => ref.invalidate(filesProvider));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(filesProvider.future),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: FilexaPageHeader(
                      title: 'Your files',
                      subtitle: '${files.length} items • ${_formatBytes(files.fold<int>(0, (sum, item) => sum + item.size))}',
                      icon: Icons.folder_copy_rounded,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CategoryStrip(
                      files: files,
                      selected: _category,
                      favoritePaths: metadata.favoritePaths,
                      onSelected: (value) => setState(() => _category = value),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${visibleFiles.length} result${visibleFiles.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(_sortLabel(_sort), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                  if (visibleFiles.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: FilexaEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matching files',
                        message: 'Try another category, search phrase or filter.',
                      ),
                    )
                  else if (_gridView)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      sliver: SliverGrid.builder(
                        itemCount: visibleFiles.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .92,
                        ),
                        itemBuilder: (context, index) => _FileGridCard(
                          item: visibleFiles[index],
                          selected: _selectedPaths.contains(visibleFiles[index].path),
                          onTap: () => _handleTap(visibleFiles[index]),
                          onLongPress: () => _toggleSelection(visibleFiles[index]),
                          onMore: () => _showFileActions(visibleFiles[index]),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      sliver: SliverList.builder(
                        itemCount: visibleFiles.length,
                        itemBuilder: (context, index) {
                          final item = visibleFiles[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FileCard(
                              item: item,
                              selected: _selectedPaths.contains(item.path),
                              onTap: () => _handleTap(item),
                              onLongPress: () => _toggleSelection(item),
                              onMore: () => _showFileActions(item),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<FileItem> _filteredAndSorted(List<FileItem> files, Set<String> favoritePaths) {
    final filtered = files.where((item) {
      final matchesQuery = _query.isEmpty || item.name.toLowerCase().contains(_query.toLowerCase());
      final matchesCategory = _category == _FileCategory.favorites
          ? favoritePaths.contains(item.path)
          : _matchesCategory(item.name, _category);
      return matchesQuery && matchesCategory;
    }).toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case _FileSort.newest:
          return b.modified.compareTo(a.modified);
        case _FileSort.oldest:
          return a.modified.compareTo(b.modified);
        case _FileSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _FileSort.size:
          return b.size.compareTo(a.size);
      }
    });
    return filtered;
  }

  void _handleTap(FileItem item) {
    if (_selectionMode) {
      _toggleSelection(item);
    } else {
      _openFile(item);
    }
  }

  void _toggleSelection(FileItem item) {
    setState(() {
      if (!_selectedPaths.add(item.path)) _selectedPaths.remove(item.path);
    });
  }

  Future<void> _openFile(FileItem item) async {
    final result = await OpenFilex.open(item.path);
    if (!mounted || result.type == ResultType.done) return;
    _showMessage(result.message);
  }

  Future<void> _shareFile(FileItem item) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(item.path)], text: item.name),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not share the file: $error');
    }
  }

  Future<void> _shareSelected(List<FileItem> files) async {
    final selected = files.where((item) => _selectedPaths.contains(item.path)).toList();
    if (selected.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(files: selected.map((item) => XFile(item.path)).toList()),
    );
  }

  Future<void> _renameFile(FileItem item) async {
    final controller = TextEditingController(text: p.basenameWithoutExtension(item.name));
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Rename')),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.trim().isEmpty) return;
    try {
      final renamed = await ref.read(fileServiceProvider).renameFile(item, newName);
      await ref.read(fileMetadataProvider.notifier).movePath(item.path, renamed.path);
      ref.invalidate(filesProvider);
      if (mounted) _showMessage('File renamed.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _deleteFile(FileItem item) async {
    final confirmed = await _confirmDelete('Delete “${item.name}” permanently?');
    if (!confirmed) return;
    try {
      await ref.read(fileServiceProvider).deleteFile(item);
      await ref.read(fileMetadataProvider.notifier).removePath(item.path);
      ref.invalidate(filesProvider);
      if (mounted) _showMessage('File deleted.');
    } catch (error) {
      if (mounted) _showMessage('Could not delete the file: $error');
    }
  }

  Future<void> _deleteSelected(List<FileItem> files) async {
    final selected = files.where((item) => _selectedPaths.contains(item.path)).toList();
    if (selected.isEmpty) return;
    final confirmed = await _confirmDelete('Delete ${selected.length} selected files permanently?');
    if (!confirmed) return;
    var failures = 0;
    for (final item in selected) {
      try {
        await ref.read(fileServiceProvider).deleteFile(item);
      } catch (_) {
        failures++;
      }
    }
    _selectedPaths.clear();
    ref.invalidate(filesProvider);
    if (mounted) _showMessage(failures == 0 ? 'Selected files deleted.' : '$failures files could not be deleted.');
  }

  Future<bool> _confirmDelete(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete files?'),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showFileActions(FileItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.open_in_new_rounded), title: const Text('Open'), onTap: () => Navigator.pop(context, 'open')),
            ListTile(
              leading: Icon(ref.read(fileMetadataProvider).valueOrNull?.favoritePaths.contains(item.path) == true ? Icons.star_rounded : Icons.star_border_rounded),
              title: Text(ref.read(fileMetadataProvider).valueOrNull?.favoritePaths.contains(item.path) == true ? 'Remove from favorites' : 'Add to favorites'),
              onTap: () => Navigator.pop(context, 'favorite'),
            ),
            ListTile(leading: const Icon(Icons.label_outline_rounded), title: const Text('Add tag'), onTap: () => Navigator.pop(context, 'tag')),
            ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Copy to folder'), onTap: () => Navigator.pop(context, 'copy')),
            ListTile(leading: const Icon(Icons.drive_file_move_rounded), title: const Text('Move to folder'), onTap: () => Navigator.pop(context, 'move')),
            ListTile(leading: const Icon(Icons.share_rounded), title: const Text('Share'), onTap: () => Navigator.pop(context, 'share')),
            ListTile(leading: const Icon(Icons.drive_file_rename_outline_rounded), title: const Text('Rename'), onTap: () => Navigator.pop(context, 'rename')),
            ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('Details'), onTap: () => Navigator.pop(context, 'details')),
            ListTile(leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error), title: const Text('Delete'), onTap: () => Navigator.pop(context, 'delete')),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'open') await _openFile(item);
    if (action == 'favorite') await ref.read(fileMetadataProvider.notifier).toggleFavorite(item.path);
    if (action == 'tag') await _setTag(item);
    if (action == 'copy') await _copyOrMove(item, move: false);
    if (action == 'move') await _copyOrMove(item, move: true);
    if (action == 'share') await _shareFile(item);
    if (action == 'rename') await _renameFile(item);
    if (action == 'details') await _showDetails(item);
    if (action == 'delete') await _deleteFile(item);
  }

  Future<void> _setTag(FileItem item) async {
    final current = ref.read(fileMetadataProvider).valueOrNull?.tags[item.path] ?? '';
    final controller = TextEditingController(text: current);
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'Work, Personal, Important…'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (current.isNotEmpty)
            TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Remove')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (tag == null) return;
    await ref.read(fileMetadataProvider.notifier).setTag(item.path, tag);
    if (mounted) _showMessage(tag.trim().isEmpty ? 'Tag removed.' : 'Tag saved.');
  }

  Future<void> _copyOrMove(FileItem item, {required bool move}) async {
    final service = ref.read(fileServiceProvider);
    final folders = await service.getManagedFolders();
    if (!mounted) return;
    final controller = TextEditingController();
    final folder = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(move ? 'Move to folder' : 'Copy to folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Folder name')),
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Existing folders', style: Theme.of(context).textTheme.labelLarge)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: folders.take(8).map((name) => ActionChip(label: Text(name), onPressed: () => controller.text = name)).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(move ? 'Move' : 'Copy')),
        ],
      ),
    );
    controller.dispose();
    if (folder == null || folder.trim().isEmpty) return;
    try {
      final result = move ? await service.moveFile(item, folder) : await service.copyFile(item, folder);
      if (move) await ref.read(fileMetadataProvider.notifier).movePath(item.path, result.path);
      ref.invalidate(filesProvider);
      if (mounted) _showMessage(move ? 'File moved.' : 'File copied.');
    } catch (error) {
      if (mounted) _showMessage('Operation failed: $error');
    }
  }

  Future<void> _showDetails(FileItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              _DetailRow(label: 'Type', value: _fileType(item.name)),
              _DetailRow(label: 'Size', value: _formatBytes(item.size)),
              _DetailRow(label: 'Modified', value: _formatDate(item.modified)),
              _DetailRow(label: 'Location', value: item.path),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.files, required this.selected, required this.favoritePaths, required this.onSelected});
  final List<FileItem> files;
  final Set<String> favoritePaths;
  final _FileCategory selected;
  final ValueChanged<_FileCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = <(_FileCategory, String, IconData, Color)>[
      (_FileCategory.all, 'All', Icons.grid_view_rounded, FilexaUi.primary),
      (_FileCategory.favorites, 'Favorites', Icons.star_rounded, const Color(0xFFF59E0B)),
      (_FileCategory.images, 'Images', Icons.image_rounded, const Color(0xFF0EA5E9)),
      (_FileCategory.videos, 'Videos', Icons.movie_rounded, const Color(0xFF2563EB)),
      (_FileCategory.audio, 'Audio', Icons.graphic_eq_rounded, const Color(0xFFEC4899)),
      (_FileCategory.documents, 'Docs', Icons.description_rounded, const Color(0xFFF97316)),
      (_FileCategory.archives, 'Archives', Icons.folder_zip_rounded, const Color(0xFFF59E0B)),
      (_FileCategory.apps, 'APK', Icons.android_rounded, const Color(0xFF22C55E)),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final count = category.$1 == _FileCategory.favorites
              ? files.where((item) => favoritePaths.contains(item.path)).length
              : files.where((item) => _matchesCategory(item.name, category.$1)).length;
          final isSelected = selected == category.$1;
          return Material(
            color: isSelected ? category.$4.withValues(alpha: .16) : FilexaUi.surface(context),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(category.$1),
              child: SizedBox(
                width: 84,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(category.$3, color: category.$4, size: 24),
                      const SizedBox(height: 5),
                      Text(category.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      Text('$count', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.item, required this.selected, required this.onTap, required this.onLongPress, required this.onMore});
  final FileItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final color = _colorForFile(item.name);
    return Material(
      color: selected ? color.withValues(alpha: .16) : FilexaUi.surface(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _FileIcon(name: item.name, selected: selected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text('${_formatBytes(item.size)} • ${_formatDate(item.modified)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(onPressed: onMore, icon: const Icon(Icons.more_vert_rounded)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileGridCard extends StatelessWidget {
  const _FileGridCard({required this.item, required this.selected, required this.onTap, required this.onLongPress, required this.onMore});
  final FileItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final color = _colorForFile(item.name);
    return Material(
      color: selected ? color.withValues(alpha: .16) : FilexaUi.surface(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FileIcon(name: item.name, selected: selected),
                  const Spacer(),
                  IconButton(onPressed: onMore, icon: const Icon(Icons.more_vert_rounded), visualDensity: VisualDensity.compact),
                ],
              ),
              const Spacer(),
              Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_formatBytes(item.size), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.name, required this.selected});
  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = _colorForFile(name);
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
      child: Icon(selected ? Icons.check_rounded : _iconForFile(name), color: color, size: 28),
    );
  }
}

class _EmptyFiles extends StatelessWidget {
  const _EmptyFiles({required this.onRefresh});
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => FilexaEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No downloaded files yet',
        message: 'Files downloaded with Filexa will appear here.',
        actionLabel: 'Refresh',
        onAction: onRefresh,
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => FilexaEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load files',
        message: message,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: SelectableText(value)),
        ]),
      );
}

bool _matchesCategory(String name, _FileCategory category) {
  if (category == _FileCategory.all) return true;
  final extension = p.extension(name).toLowerCase();
  switch (category) {
    case _FileCategory.all:
      return true;
    case _FileCategory.favorites:
      return false;
    case _FileCategory.images:
      return {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'}.contains(extension);
    case _FileCategory.videos:
      return {'.mp4', '.mkv', '.mov', '.avi', '.webm', '.mpeg'}.contains(extension);
    case _FileCategory.audio:
      return {'.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'}.contains(extension);
    case _FileCategory.documents:
      return {'.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.epub'}.contains(extension);
    case _FileCategory.archives:
      return {'.zip', '.rar', '.7z', '.tar', '.gz', '.iso'}.contains(extension);
    case _FileCategory.apps:
      return extension == '.apk';
  }
}

IconData _iconForFile(String name) {
  final extension = p.extension(name).toLowerCase();
  if ({'.jpg', '.jpeg', '.png', '.gif', '.webp'}.contains(extension)) return Icons.image_rounded;
  if ({'.mp4', '.mkv', '.mov', '.avi', '.webm'}.contains(extension)) return Icons.movie_rounded;
  if ({'.mp3', '.wav', '.m4a', '.aac', '.ogg'}.contains(extension)) return Icons.audio_file_rounded;
  if (extension == '.pdf') return Icons.picture_as_pdf_rounded;
  if ({'.zip', '.rar', '.7z', '.tar', '.gz', '.iso'}.contains(extension)) return Icons.folder_zip_rounded;
  if (extension == '.apk') return Icons.android_rounded;
  if ({'.doc', '.docx', '.txt', '.epub'}.contains(extension)) return Icons.description_rounded;
  if ({'.xls', '.xlsx'}.contains(extension)) return Icons.table_chart_rounded;
  if ({'.ppt', '.pptx'}.contains(extension)) return Icons.slideshow_rounded;
  return Icons.insert_drive_file_rounded;
}

Color _colorForFile(String name) {
  final extension = p.extension(name).toLowerCase();
  if ({'.jpg', '.jpeg', '.png', '.gif', '.webp'}.contains(extension)) return const Color(0xFF0EA5E9);
  if ({'.mp4', '.mkv', '.mov', '.avi', '.webm'}.contains(extension)) return const Color(0xFF2563EB);
  if ({'.mp3', '.wav', '.m4a', '.aac', '.ogg'}.contains(extension)) return const Color(0xFFEC4899);
  if (extension == '.pdf') return const Color(0xFFEF4444);
  if ({'.zip', '.rar', '.7z', '.tar', '.gz', '.iso'}.contains(extension)) return const Color(0xFFF59E0B);
  if (extension == '.apk') return const Color(0xFF22C55E);
  if ({'.xls', '.xlsx'}.contains(extension)) return const Color(0xFF16A34A);
  if ({'.ppt', '.pptx'}.contains(extension)) return const Color(0xFFF97316);
  return FilexaUi.primary;
}

String _fileType(String name) {
  final extension = p.extension(name).replaceFirst('.', '').toUpperCase();
  return extension.isEmpty ? 'File' : '$extension file';
}

String _sortLabel(_FileSort sort) {
  switch (sort) {
    case _FileSort.newest:
      return 'Newest';
    case _FileSort.oldest:
      return 'Oldest';
    case _FileSort.name:
      return 'Name';
    case _FileSort.size:
      return 'Largest';
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
