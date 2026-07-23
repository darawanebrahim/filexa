import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_item.dart';
import '../../core/providers/file_provider.dart';
import '../../theme/filexa_ui.dart';

enum _FileCategory { all, documents, images, videos, audio, archives, apk, recent }
enum _FileSort { newest, oldest, name, size }

class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  String _query = '';
  bool _showSearch = false;
  _FileCategory _category = _FileCategory.all;
  _FileSort _sort = _FileSort.newest;

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(filesProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: _showSearch
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search files',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              )
            : const Text('File Hub', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        actions: [
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
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(filesProvider),
            icon: const Icon(Icons.refresh_rounded),
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
            final visibleFiles = _filteredAndSorted(files);

            if (files.isEmpty) {
              return _EmptyFiles(onRefresh: () => ref.invalidate(filesProvider));
            }

            return RefreshIndicator(
              onRefresh: () async => ref.refresh(filesProvider.future),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: FilexaPageHeader(
                      title: 'Your file hub',
                      subtitle: '${files.length} file${files.length == 1 ? '' : 's'} organized in one place',
                      icon: Icons.folder_copy_rounded,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CategoryGrid(
                      files: files,
                      selected: _category,
                      onSelected: (value) => setState(() => _category = value),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _categoryTitle(_category),
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            '${visibleFiles.length} item${visibleFiles.length == 1 ? '' : 's'}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (visibleFiles.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoMatchingFiles(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList.builder(
                        itemCount: visibleFiles.length,
                        itemBuilder: (context, index) {
                          final item = visibleFiles[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FileCard(
                              item: item,
                              onOpen: () => _openFile(item),
                              onShare: () => _shareFile(item),
                              onRename: () => _renameFile(item),
                              onDelete: () => _deleteFile(item),
                              onDetails: () => _showDetails(item),
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

  List<FileItem> _filteredAndSorted(List<FileItem> files) {
    final now = DateTime.now();
    final result = files.where((item) {
      final matchesQuery = _query.isEmpty || item.name.toLowerCase().contains(_query.toLowerCase());
      if (!matchesQuery) return false;
      return switch (_category) {
        _FileCategory.all => true,
        _FileCategory.documents => _isDocument(item.name),
        _FileCategory.images => _isImage(item.name),
        _FileCategory.videos => _isVideo(item.name),
        _FileCategory.audio => _isAudio(item.name),
        _FileCategory.archives => _isArchive(item.name),
        _FileCategory.apk => p.extension(item.name).toLowerCase() == '.apk',
        _FileCategory.recent => now.difference(item.modified).inDays <= 7,
      };
    }).toList();

    switch (_sort) {
      case _FileSort.newest:
        result.sort((a, b) => b.modified.compareTo(a.modified));
      case _FileSort.oldest:
        result.sort((a, b) => a.modified.compareTo(b.modified));
      case _FileSort.name:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _FileSort.size:
        result.sort((a, b) => b.size.compareTo(a.size));
    }
    return result;
  }

  Future<void> _openFile(FileItem item) async {
    final result = await OpenFilex.open(item.path);
    if (!mounted || result.type == ResultType.done) return;
    _showMessage(result.message);
  }

  Future<void> _shareFile(FileItem item) async {
    try {
      await Share.shareXFiles([XFile(item.path)], text: item.name);
    } catch (error) {
      if (mounted) _showMessage('Could not share the file: $error');
    }
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
      await ref.read(fileServiceProvider).renameFile(item, newName);
      ref.invalidate(filesProvider);
      if (mounted) _showMessage('File renamed.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _deleteFile(FileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('“${item.name}” will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(fileServiceProvider).deleteFile(item);
      ref.invalidate(filesProvider);
      if (mounted) _showMessage('File deleted.');
    } catch (error) {
      if (mounted) _showMessage('Could not delete the file: $error');
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

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.files, required this.selected, required this.onSelected});

  final List<FileItem> files;
  final _FileCategory selected;
  final ValueChanged<_FileCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(_FileCategory, IconData, String, int)>[
      (_FileCategory.all, Icons.grid_view_rounded, 'All files', files.length),
      (_FileCategory.documents, Icons.description_rounded, 'Documents', files.where((e) => _isDocument(e.name)).length),
      (_FileCategory.images, Icons.image_rounded, 'Images', files.where((e) => _isImage(e.name)).length),
      (_FileCategory.videos, Icons.movie_rounded, 'Videos', files.where((e) => _isVideo(e.name)).length),
      (_FileCategory.audio, Icons.audio_file_rounded, 'Audio', files.where((e) => _isAudio(e.name)).length),
      (_FileCategory.archives, Icons.folder_zip_rounded, 'Archives', files.where((e) => _isArchive(e.name)).length),
      (_FileCategory.apk, Icons.android_rounded, 'APK', files.where((e) => p.extension(e.name).toLowerCase() == '.apk').length),
      (_FileCategory.recent, Icons.history_rounded, 'Recent', files.where((e) => DateTime.now().difference(e.modified).inDays <= 7).length),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .82,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selected == item.$1;
          final scheme = Theme.of(context).colorScheme;
          return Material(
            color: isSelected ? scheme.primaryContainer : FilexaUi.surface(context),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => onSelected(item.$1),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.$2, color: isSelected ? scheme.primary : scheme.onSurfaceVariant, size: 27),
                    const SizedBox(height: 7),
                    Text(item.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${item.$4}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
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
  const _FileCard({
    required this.item,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
    required this.onDetails,
  });

  final FileItem item;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForFile(item.name);
    return Container(
      decoration: FilexaUi.cardDecoration(context, radius: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: FilexaUi.softSurface(context), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(
                        '${_formatBytes(item.size)} • ${_formatDate(item.modified)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'open': onOpen();
                      case 'share': onShare();
                      case 'rename': onRename();
                      case 'details': onDetails();
                      case 'delete': onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'open', child: Text('Open')),
                    PopupMenuItem(value: 'share', child: Text('Share')),
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'details', child: Text('Details')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFiles extends StatelessWidget {
  const _EmptyFiles({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded, size: 68, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No downloaded files yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Files downloaded with Filexa will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}

class _NoMatchingFiles extends StatelessWidget {
  const _NoMatchingFiles();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('No matching files found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Try another category or search term.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 60, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 14),
            const Text('Could not load files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

bool _isDocument(String name) {
  return const {'.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.epub', '.csv'}
      .contains(p.extension(name).toLowerCase());
}

bool _isImage(String name) {
  return const {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp'}
      .contains(p.extension(name).toLowerCase());
}

bool _isVideo(String name) {
  return const {'.mp4', '.mkv', '.mov', '.avi', '.webm', '.mpeg', '.m4v'}
      .contains(p.extension(name).toLowerCase());
}

bool _isAudio(String name) {
  return const {'.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'}
      .contains(p.extension(name).toLowerCase());
}

bool _isArchive(String name) {
  return const {'.zip', '.rar', '.7z', '.tar', '.gz', '.iso'}
      .contains(p.extension(name).toLowerCase());
}

String _categoryTitle(_FileCategory category) => switch (category) {
  _FileCategory.all => 'All files',
  _FileCategory.documents => 'Documents',
  _FileCategory.images => 'Images',
  _FileCategory.videos => 'Videos',
  _FileCategory.audio => 'Audio',
  _FileCategory.archives => 'Archives',
  _FileCategory.apk => 'APK files',
  _FileCategory.recent => 'Recent files',
};

IconData _iconForFile(String name) {
  final extension = p.extension(name).toLowerCase();
  return switch (extension) {
    '.jpg' || '.jpeg' || '.png' || '.gif' || '.webp' || '.svg' => Icons.image_rounded,
    '.mp4' || '.mkv' || '.mov' || '.avi' || '.webm' => Icons.movie_rounded,
    '.mp3' || '.wav' || '.m4a' || '.aac' || '.ogg' || '.flac' => Icons.audio_file_rounded,
    '.pdf' => Icons.picture_as_pdf_rounded,
    '.zip' || '.rar' || '.7z' || '.tar' => Icons.folder_zip_rounded,
    '.doc' || '.docx' || '.txt' || '.epub' => Icons.description_rounded,
    '.xls' || '.xlsx' || '.csv' => Icons.table_chart_rounded,
    '.ppt' || '.pptx' => Icons.slideshow_rounded,
    '.apk' => Icons.android_rounded,
    _ => Icons.insert_drive_file_rounded,
  };
}

String _fileType(String name) {
  final extension = p.extension(name).replaceFirst('.', '').toUpperCase();
  return extension.isEmpty ? 'File' : '$extension file';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
