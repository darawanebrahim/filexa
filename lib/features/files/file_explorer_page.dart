import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/services/file_service.dart';
import '../../theme/filexa_ui.dart';

enum _ExplorerSort { name, newest, oldest, size }

class FileExplorerPage extends StatefulWidget {
  const FileExplorerPage({super.key, required this.fileService});

  final FileService fileService;

  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  Directory? _root;
  Directory? _currentDirectory;
  List<FileSystemEntity> _entities = const [];
  final List<String> _recentDirectories = <String>[];
  final Set<String> _selectedPaths = <String>{};
  bool _loading = true;
  bool _gridView = false;
  bool _showHidden = false;
  String? _error;
  _ExplorerSort _sort = _ExplorerSort.name;

  bool get _selectionMode => _selectedPaths.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final root = await widget.fileService.getFilexaDirectory();
      if (!await root.exists()) await root.create(recursive: true);
      if (!mounted) return;
      _root = root;
      _currentDirectory = root;
      await _loadDirectory(root);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadDirectory(Directory directory) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedPaths.clear();
    });
    try {
      final entities = <FileSystemEntity>[];
      await for (final entity in directory.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (!_showHidden && name.startsWith('.')) continue;
        entities.add(entity);
      }
      await _sortEntities(entities);
      if (!mounted) return;
      setState(() {
        _currentDirectory = directory;
        _entities = entities;
        _loading = false;
        _rememberDirectory(directory.path);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _sortEntities(List<FileSystemEntity> entities) async {
    final stats = <String, FileStat>{};
    if (_sort != _ExplorerSort.name) {
      for (final entity in entities) {
        try {
          stats[entity.path] = await entity.stat();
        } on FileSystemException {
          // Entity may disappear while the folder is being read.
        }
      }
    }
    entities.sort((a, b) {
      if (a is Directory && b is! Directory) return -1;
      if (a is! Directory && b is Directory) return 1;
      switch (_sort) {
        case _ExplorerSort.name:
          return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
        case _ExplorerSort.newest:
          return (stats[b.path]?.modified ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(stats[a.path]?.modified ?? DateTime.fromMillisecondsSinceEpoch(0));
        case _ExplorerSort.oldest:
          return (stats[a.path]?.modified ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(stats[b.path]?.modified ?? DateTime.fromMillisecondsSinceEpoch(0));
        case _ExplorerSort.size:
          return (stats[b.path]?.size ?? 0).compareTo(stats[a.path]?.size ?? 0);
      }
    });
  }

  void _rememberDirectory(String path) {
    _recentDirectories.remove(path);
    _recentDirectories.insert(0, path);
    if (_recentDirectories.length > 6) _recentDirectories.removeLast();
  }

  Future<bool> _handleBack() async {
    if (_selectionMode) {
      setState(_selectedPaths.clear);
      return false;
    }
    final root = _root;
    final current = _currentDirectory;
    if (root == null || current == null || p.equals(root.path, current.path)) return true;
    await _loadDirectory(current.parent);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _handleBack();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () async {
              final shouldPop = await _handleBack();
              if (shouldPop && context.mounted) Navigator.of(context).pop();
            },
            icon: Icon(_selectionMode ? Icons.close_rounded : Icons.arrow_back_rounded),
          ),
          title: Text(_selectionMode ? '${_selectedPaths.length} selected' : 'File Explorer Pro'),
          actions: _selectionMode
              ? [
                  IconButton(
                    tooltip: 'Select all',
                    onPressed: () => setState(() => _selectedPaths.addAll(_entities.map((e) => e.path))),
                    icon: const Icon(Icons.select_all_rounded),
                  ),
                  IconButton(
                    tooltip: 'Delete selected',
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ]
              : [
                  IconButton(
                    tooltip: _showHidden ? 'Hide hidden files' : 'Show hidden files',
                    onPressed: () async {
                      setState(() => _showHidden = !_showHidden);
                      final current = _currentDirectory;
                      if (current != null) await _loadDirectory(current);
                    },
                    icon: Icon(_showHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  ),
                  PopupMenuButton<_ExplorerSort>(
                    tooltip: 'Sort',
                    initialValue: _sort,
                    onSelected: (value) async {
                      setState(() => _sort = value);
                      final current = _currentDirectory;
                      if (current != null) await _loadDirectory(current);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _ExplorerSort.name, child: Text('Name')),
                      PopupMenuItem(value: _ExplorerSort.newest, child: Text('Newest first')),
                      PopupMenuItem(value: _ExplorerSort.oldest, child: Text('Oldest first')),
                      PopupMenuItem(value: _ExplorerSort.size, child: Text('Largest first')),
                    ],
                  ),
                  IconButton(
                    tooltip: _gridView ? 'List view' : 'Grid view',
                    onPressed: () => setState(() => _gridView = !_gridView),
                    icon: Icon(_gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                  ),
                ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createFolder,
          icon: const Icon(Icons.create_new_folder_rounded),
          label: const Text('New folder'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildBreadcrumbs(),
              if (_recentDirectories.length > 1) _buildRecentLocations(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    final root = _root;
    final current = _currentDirectory;
    if (root == null || current == null) return const SizedBox.shrink();
    final relative = p.relative(current.path, from: root.path);
    final segments = relative == '.' ? <String>[] : p.split(relative);
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          ActionChip(
            avatar: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Filexa'),
            onPressed: () => _loadDirectory(root),
          ),
          for (var i = 0; i < segments.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right_rounded, size: 18),
            ),
            ActionChip(
              label: Text(segments[i]),
              onPressed: () {
                final path = p.joinAll([root.path, ...segments.take(i + 1)]);
                _loadDirectory(Directory(path));
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentLocations() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _recentDirectories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final path = _recentDirectories[index];
          return InputChip(
            avatar: const Icon(Icons.history_rounded, size: 16),
            label: Text(p.basename(path).isEmpty ? path : p.basename(path)),
            onPressed: () => _loadDirectory(Directory(path)),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return FilexaEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not open this folder',
        message: _error!,
        actionLabel: 'Try again',
        onAction: () {
          final current = _currentDirectory;
          if (current != null) _loadDirectory(current);
        },
      );
    }
    if (_entities.isEmpty) {
      return const FilexaEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'This folder is empty',
        message: 'Create a folder or move files here to organize your workspace.',
      );
    }
    if (_gridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: .95,
        ),
        itemCount: _entities.length,
        itemBuilder: (_, index) => _ExplorerGridTile(
          entity: _entities[index],
          selected: _selectedPaths.contains(_entities[index].path),
          onTap: () => _handleEntityTap(_entities[index]),
          onLongPress: () => _toggleSelection(_entities[index]),
          onMore: () => _showEntityActions(_entities[index]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: _entities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _ExplorerListTile(
        entity: _entities[index],
        selected: _selectedPaths.contains(_entities[index].path),
        onTap: () => _handleEntityTap(_entities[index]),
        onLongPress: () => _toggleSelection(_entities[index]),
        onMore: () => _showEntityActions(_entities[index]),
      ),
    );
  }

  void _handleEntityTap(FileSystemEntity entity) {
    if (_selectionMode) {
      _toggleSelection(entity);
    } else if (entity is Directory) {
      _loadDirectory(entity);
    } else {
      _openFile(entity as File);
    }
  }

  void _toggleSelection(FileSystemEntity entity) {
    setState(() {
      if (!_selectedPaths.add(entity.path)) _selectedPaths.remove(entity.path);
    });
  }

  Future<void> _openFile(File file) async {
    final result = await OpenFilex.open(file.path);
    if (!mounted || result.type == ResultType.done) return;
    _showMessage(result.message);
  }

  Future<void> _createFolder() async {
    var folderName = '';
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: 'Create folder',
        subtitle: 'Add a new folder without leaving your current location',
        icon: Icons.create_new_folder_rounded,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: TextFormField(
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            onChanged: (value) => folderName = value.trim(),
            onFieldSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) Navigator.pop(sheetContext, trimmed);
            },
          ),
        ),
        footer: Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  final trimmed = folderName.trim();
                  Navigator.pop(sheetContext, trimmed.isEmpty ? null : trimmed);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );

    final current = _currentDirectory;
    if (name == null || name.trim().isEmpty || current == null) return;
    try {
      final safeName = _sanitizeName(name);
      final folder = Directory(p.join(current.path, safeName));
      if (await folder.exists()) throw const FileSystemException('A folder with this name already exists.');
      await folder.create(recursive: true);
      await _loadDirectory(current);
      _showMessage('Folder created.');
    } catch (error) {
      _showMessage('Could not create folder: $error');
    }
  }

  Future<void> _showEntityActions(FileSystemEntity entity) async {
    final name = p.basename(entity.path);
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: name,
        subtitle: entity is Directory ? 'Folder actions' : 'Smart file actions',
        icon: entity is Directory ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              FilexaSheetActionCard(
                icon: entity is Directory ? Icons.folder_open_rounded : Icons.open_in_new_rounded,
                title: entity is Directory ? 'Open folder' : 'Open file',
                subtitle: entity is Directory ? 'Browse this location' : 'Open with the best available viewer',
                onTap: () => Navigator.pop(sheetContext, 'open'),
              ),
              if (entity is File)
                FilexaSheetActionCard(
                  icon: Icons.share_rounded,
                  title: 'Share',
                  subtitle: 'Send this file securely to another app',
                  onTap: () => Navigator.pop(sheetContext, 'share'),
                ),
              FilexaSheetActionCard(
                icon: Icons.drive_file_rename_outline_rounded,
                title: 'Rename',
                subtitle: 'Change the name without moving the item',
                onTap: () => Navigator.pop(sheetContext, 'rename'),
              ),
              FilexaSheetActionCard(
                icon: Icons.info_outline_rounded,
                title: 'Details',
                subtitle: 'Size, modified date and storage location',
                onTap: () => Navigator.pop(sheetContext, 'details'),
              ),
              FilexaSheetActionCard(
                icon: Icons.delete_outline_rounded,
                title: 'Delete',
                subtitle: 'Permanently remove this item after confirmation',
                destructive: true,
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'open') _handleEntityTap(entity);
    if (action == 'share' && entity is File) {
      await SharePlus.instance.share(ShareParams(files: [XFile(entity.path)]));
    }
    if (action == 'rename') await _renameEntity(entity);
    if (action == 'details') await _showDetails(entity);
    if (action == 'delete') await _deleteEntity(entity);
  }

  Future<void> _renameEntity(FileSystemEntity entity) async {
    final oldName = p.basename(entity.path);
    var newValue = entity is File ? p.basenameWithoutExtension(oldName) : oldName;
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: entity is Directory ? 'Rename folder' : 'Rename file',
        subtitle: oldName,
        icon: Icons.drive_file_rename_outline_rounded,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: TextFormField(
            initialValue: newValue,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'New name',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
            onChanged: (text) => newValue = text.trim(),
            onFieldSubmitted: (text) {
              final trimmed = text.trim();
              if (trimmed.isNotEmpty) Navigator.pop(sheetContext, trimmed);
            },
          ),
        ),
        footer: Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, newValue.trim().isEmpty ? null : newValue.trim()),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Rename'),
              ),
            ),
          ],
        ),
      ),
    );

    final current = _currentDirectory;
    if (value == null || value.trim().isEmpty || current == null) return;
    try {
      var newName = _sanitizeName(value);
      if (entity is File && p.extension(newName).isEmpty) newName += p.extension(oldName);
      final target = p.join(p.dirname(entity.path), newName);
      if (await FileSystemEntity.type(target) != FileSystemEntityType.notFound) {
        throw const FileSystemException('An item with this name already exists.');
      }
      await entity.rename(target);
      await _loadDirectory(current);
      _showMessage('Item renamed.');
    } catch (error) {
      _showMessage('Could not rename item: $error');
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final confirmed = await _confirmDelete('Delete “${p.basename(entity.path)}” permanently?');
    if (!confirmed) return;
    final current = _currentDirectory;
    if (current == null) return;
    try {
      await entity.delete(recursive: true);
      await _loadDirectory(current);
      _showMessage('Item deleted.');
    } catch (error) {
      _showMessage('Could not delete item: $error');
    }
  }

  Future<void> _deleteSelected() async {
    final confirmed = await _confirmDelete('Delete ${_selectedPaths.length} selected items permanently?');
    if (!confirmed) return;
    var failures = 0;
    for (final path in _selectedPaths.toList()) {
      try {
        final type = await FileSystemEntity.type(path);
        if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else if (type == FileSystemEntityType.file) {
          await File(path).delete();
        }
      } catch (_) {
        failures++;
      }
    }
    final current = _currentDirectory;
    if (current != null) await _loadDirectory(current);
    _showMessage(failures == 0 ? 'Selected items deleted.' : '$failures items could not be deleted.');
  }

  Future<bool> _confirmDelete(String message) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: 'Delete permanently?',
        subtitle: 'This action cannot be undone from Filexa yet',
        icon: Icons.delete_forever_rounded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: FilexaUi.cardDecoration(sheetContext, radius: 18, elevated: false),
            child: Text(message),
          ),
        ),
        footer: Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetContext, false), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(sheetContext).colorScheme.error),
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _showDetails(FileSystemEntity entity) async {
    final stat = await entity.stat();
    if (!mounted) return;
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
              Text(p.basename(entity.path), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              _InfoRow(label: 'Type', value: entity is Directory ? 'Folder' : p.extension(entity.path).replaceFirst('.', '').toUpperCase()),
              _InfoRow(label: 'Size', value: entity is Directory ? 'Calculated when opened' : _formatBytes(stat.size)),
              _InfoRow(label: 'Modified', value: _formatDate(stat.modified)),
              _InfoRow(label: 'Location', value: entity.path),
            ],
          ),
        ),
      ),
    );
  }

  String _sanitizeName(String value) => value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExplorerListTile extends StatelessWidget {
  const _ExplorerListTile({required this.entity, required this.selected, required this.onTap, required this.onLongPress, required this.onMore});

  final FileSystemEntity entity;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final isDirectory = entity is Directory;
    return Material(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : FilexaUi.surface(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: (isDirectory ? const Color(0xFFF59E0B) : FilexaUi.primary).withValues(alpha: .14),
                child: Icon(isDirectory ? Icons.folder_rounded : _iconForFile(entity.path), color: isDirectory ? const Color(0xFFF59E0B) : FilexaUi.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.basename(entity.path), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    FutureBuilder<FileStat>(
                      future: entity.stat(),
                      builder: (_, snapshot) {
                        final stat = snapshot.data;
                        final subtitle = isDirectory
                            ? 'Folder'
                            : '${stat == null ? '…' : _formatBytes(stat.size)} • ${stat == null ? '…' : _formatDate(stat.modified)}';
                        return Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant));
                      },
                    ),
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

class _ExplorerGridTile extends StatelessWidget {
  const _ExplorerGridTile({required this.entity, required this.selected, required this.onTap, required this.onLongPress, required this.onMore});

  final FileSystemEntity entity;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final isDirectory = entity is Directory;
    return Material(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : FilexaUi.surface(context),
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
                  Icon(isDirectory ? Icons.folder_rounded : _iconForFile(entity.path), size: 38, color: isDirectory ? const Color(0xFFF59E0B) : FilexaUi.primary),
                  const Spacer(),
                  IconButton(onPressed: onMore, icon: const Icon(Icons.more_vert_rounded), visualDensity: VisualDensity.compact),
                ],
              ),
              const Spacer(),
              Text(p.basename(entity.path), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(isDirectory ? 'Folder' : p.extension(entity.path).replaceFirst('.', '').toUpperCase(), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 82, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

IconData _iconForFile(String path) {
  final extension = p.extension(path).toLowerCase();
  if (<String>{'.jpg', '.jpeg', '.png', '.gif', '.webp'}.contains(extension)) return Icons.image_rounded;
  if (<String>{'.mp4', '.mkv', '.mov', '.avi', '.webm'}.contains(extension)) return Icons.movie_rounded;
  if (<String>{'.mp3', '.wav', '.m4a', '.aac', '.flac'}.contains(extension)) return Icons.audio_file_rounded;
  if (extension == '.pdf') return Icons.picture_as_pdf_rounded;
  if (<String>{'.zip', '.rar', '.7z', '.tar', '.gz'}.contains(extension)) return Icons.folder_zip_rounded;
  if (extension == '.apk') return Icons.android_rounded;
  return Icons.insert_drive_file_rounded;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
