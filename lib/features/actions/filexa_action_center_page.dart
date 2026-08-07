import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_item.dart';
import '../../core/providers/file_metadata_provider.dart';
import '../../core/providers/file_provider.dart';
import '../../theme/filexa_ui.dart';
import '../documents/code_document_viewer.dart';
import '../documents/html_document_viewer.dart';
import '../documents/office_studio_page.dart';

enum _ActionCategory { all, pdf, images, media, code, archives, apps, documents }

class FilexaActionCenterPage extends ConsumerStatefulWidget {
  const FilexaActionCenterPage({super.key});

  @override
  ConsumerState<FilexaActionCenterPage> createState() => _FilexaActionCenterPageState();
}

class _FilexaActionCenterPageState extends ConsumerState<FilexaActionCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  _ActionCategory _category = _ActionCategory.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(filesProvider);
    final metadata = ref.watch(fileMetadataProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filexa Action Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh files',
            onPressed: () => ref.invalidate(filesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: filesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => FilexaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Files could not be loaded',
            message: '$error',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(filesProvider),
          ),
          data: (files) {
            final visible = _filtered(files);
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(filesProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                    child: FilexaPageHeader(
                      title: 'Smart actions for every file',
                      subtitle: 'Open, share, inspect, copy the path or use a specialized viewer.',
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildSearchAndFilters(context)),
                  if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: FilexaEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matching files',
                        message: 'Try another name or file category.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                      sliver: SliverList.separated(
                        itemCount: visible.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          final favorite = metadata?.favoritePaths.contains(item.path) ?? false;
                          return _ActionFileCard(
                            item: item,
                            favorite: favorite,
                            onTap: () => _showActions(item),
                            onFavorite: () => ref
                                .read(fileMetadataProvider.notifier)
                                .toggleFavorite(item.path),
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

  Widget _buildSearchAndFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search files for an action',
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
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _ActionCategory.values.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _ActionCategory.values[index];
                return ChoiceChip(
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                  avatar: Icon(_categoryIcon(category), size: 18),
                  label: Text(_categoryLabel(category)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<FileItem> _filtered(List<FileItem> files) {
    final query = _searchController.text.trim().toLowerCase();
    final result = files.where((item) {
      final matchesQuery = query.isEmpty || item.name.toLowerCase().contains(query);
      final matchesCategory = _category == _ActionCategory.all || _categoryFor(item.name) == _category;
      return matchesQuery && matchesCategory;
    }).toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  Future<void> _showActions(FileItem item) async {
    final category = _categoryFor(item.name);
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: item.name,
        subtitle: '${_formatBytes(item.size)} • ${_categoryLabel(category)}',
        icon: _categoryIcon(category),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              FilexaSheetActionCard(
                icon: Icons.open_in_new_rounded,
                title: 'Smart open',
                subtitle: 'Use Filexa when an internal viewer is available',
                onTap: () => Navigator.pop(sheetContext, 'open'),
              ),
              if (_isHtml(item.name))
                FilexaSheetActionCard(
                  icon: Icons.language_rounded,
                  title: 'Open as webpage',
                  subtitle: 'Render this HTML file inside Filexa',
                  onTap: () => Navigator.pop(sheetContext, 'html'),
                ),
              if (_isCode(item.name))
                FilexaSheetActionCard(
                  icon: Icons.code_rounded,
                  title: 'Open as code',
                  subtitle: 'Source-friendly view with search and line numbers',
                  onTap: () => Navigator.pop(sheetContext, 'code'),
                ),
              if (category == _ActionCategory.pdf)
                FilexaSheetActionCard(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'PDF workspace',
                  subtitle: 'Open PDF tools, details and safe file actions',
                  onTap: () => Navigator.pop(sheetContext, 'pdf_tools'),
                ),
              if (const {'.docx', '.xlsx', '.pptx'}.contains(p.extension(item.name).toLowerCase()))
                FilexaSheetActionCard(
                  icon: Icons.business_center_rounded,
                  title: 'Open in Office Studio',
                  subtitle: 'Edit Office content natively inside Filexa',
                  onTap: () => Navigator.pop(sheetContext, 'office'),
                ),
              FilexaSheetActionCard(
                icon: Icons.share_rounded,
                title: 'Share',
                subtitle: 'Send the original file to another app',
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
              FilexaSheetActionCard(
                icon: Icons.content_copy_rounded,
                title: 'Copy file location',
                subtitle: item.path,
                onTap: () => Navigator.pop(sheetContext, 'copy_path'),
              ),
              FilexaSheetActionCard(
                icon: Icons.info_outline_rounded,
                title: 'File details',
                subtitle: 'Type, size, modified date and location',
                onTap: () => Navigator.pop(sheetContext, 'details'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _openSmart(item);
        return;
      case 'html':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => HtmlDocumentViewer(path: item.path)),
        );
        return;
      case 'code':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CodeDocumentViewer(path: item.path)),
        );
        return;
      case 'pdf_tools':
        await _showPdfTools(item);
        return;
      case 'office':
        await openOfficeFile(context, item);
        return;
      case 'share':
        await SharePlus.instance.share(
          ShareParams(files: [XFile(item.path)], subject: item.name),
        );
        return;
      case 'copy_path':
        await Clipboard.setData(ClipboardData(text: item.path));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File location copied')),
        );
        return;
      case 'details':
        await _showDetails(item);
        return;
    }
  }

  Future<void> _openSmart(FileItem item) async {
    if (_isHtml(item.name)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => HtmlDocumentViewer(path: item.path)),
      );
      return;
    }
    if (_isCode(item.name)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CodeDocumentViewer(path: item.path)),
      );
      return;
    }
    if (const {'.docx', '.xlsx', '.pptx'}.contains(p.extension(item.name).toLowerCase())) {
      await openOfficeFile(context, item);
      return;
    }
    final result = await OpenFilex.open(item.path);
    if (!mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message.isEmpty ? 'No compatible viewer was found.' : result.message)),
    );
  }

  Future<void> _showPdfTools(FileItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: 'PDF workspace',
        subtitle: item.name,
        icon: Icons.picture_as_pdf_rounded,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              FilexaSheetActionCard(
                icon: Icons.open_in_new_rounded,
                title: 'Open PDF',
                subtitle: 'Read this PDF now',
                onTap: () => Navigator.pop(sheetContext, 'open'),
              ),
              FilexaSheetActionCard(
                icon: Icons.share_rounded,
                title: 'Share PDF',
                subtitle: 'Send the original PDF to another app',
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
              FilexaSheetActionCard(
                icon: Icons.content_copy_rounded,
                title: 'Copy PDF location',
                subtitle: item.path,
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
              FilexaSheetActionCard(
                icon: Icons.info_outline_rounded,
                title: 'PDF information',
                subtitle: 'Inspect size, date and storage location',
                onTap: () => Navigator.pop(sheetContext, 'details'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _openSmart(item);
        return;
      case 'share':
        await SharePlus.instance.share(ShareParams(files: [XFile(item.path)], subject: item.name));
        return;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: item.path));
        return;
      case 'details':
        await _showDetails(item);
        return;
    }
  }

  Future<void> _showDetails(FileItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: 'File details',
        subtitle: item.name,
        icon: Icons.info_outline_rounded,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: FilexaUi.cardDecoration(sheetContext, radius: 20, elevated: false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Name', value: item.name),
                _DetailRow(label: 'Category', value: _categoryLabel(_categoryFor(item.name))),
                _DetailRow(label: 'Extension', value: p.extension(item.name).isEmpty ? 'None' : p.extension(item.name)),
                _DetailRow(label: 'Size', value: _formatBytes(item.size)),
                _DetailRow(label: 'Modified', value: item.modified.toLocal().toString().split('.').first),
                _DetailRow(label: 'Location', value: item.path),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionFileCard extends StatelessWidget {
  const _ActionFileCard({
    required this.item,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });

  final FileItem item;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final category = _categoryFor(item.name);
    return Container(
      decoration: FilexaUi.cardDecoration(context, radius: 20, elevated: false),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        leading: _FileTypeIcon(name: item.name),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${_formatBytes(item.size)} • ${_categoryLabel(category)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: favorite ? 'Remove favorite' : 'Add favorite',
              onPressed: onFavorite,
              icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _FileTypeIcon extends StatelessWidget {
  const _FileTypeIcon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final category = _categoryFor(name);
    final color = _categoryColor(category);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(_categoryIcon(category), color: color),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

_ActionCategory _categoryFor(String name) {
  final extension = p.extension(name).toLowerCase();
  if (extension == '.pdf') return _ActionCategory.pdf;
  if (const {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic'}.contains(extension)) {
    return _ActionCategory.images;
  }
  if (const {'.mp4', '.mkv', '.mov', '.avi', '.webm', '.mp3', '.wav', '.m4a', '.aac', '.flac'}.contains(extension)) {
    return _ActionCategory.media;
  }
  if (_codeExtensions.contains(extension) || _htmlExtensions.contains(extension)) return _ActionCategory.code;
  if (const {'.zip', '.rar', '.7z', '.tar', '.gz'}.contains(extension)) return _ActionCategory.archives;
  if (extension == '.apk' || extension == '.aab') return _ActionCategory.apps;
  return _ActionCategory.documents;
}

bool _isHtml(String name) => _htmlExtensions.contains(p.extension(name).toLowerCase());
bool _isCode(String name) => _codeExtensions.contains(p.extension(name).toLowerCase());

const Set<String> _htmlExtensions = {'.html', '.htm'};
const Set<String> _codeExtensions = {
  '.txt', '.md', '.json', '.xml', '.css', '.js', '.ts', '.php', '.dart',
  '.yaml', '.yml', '.log', '.csv', '.srt', '.vtt', '.java', '.kt', '.py',
};

String _categoryLabel(_ActionCategory category) => switch (category) {
      _ActionCategory.all => 'All',
      _ActionCategory.pdf => 'PDF',
      _ActionCategory.images => 'Images',
      _ActionCategory.media => 'Media',
      _ActionCategory.code => 'Code',
      _ActionCategory.archives => 'Archives',
      _ActionCategory.apps => 'Apps',
      _ActionCategory.documents => 'Documents',
    };

IconData _categoryIcon(_ActionCategory category) => switch (category) {
      _ActionCategory.all => Icons.dashboard_rounded,
      _ActionCategory.pdf => Icons.picture_as_pdf_rounded,
      _ActionCategory.images => Icons.image_rounded,
      _ActionCategory.media => Icons.perm_media_rounded,
      _ActionCategory.code => Icons.code_rounded,
      _ActionCategory.archives => Icons.archive_rounded,
      _ActionCategory.apps => Icons.android_rounded,
      _ActionCategory.documents => Icons.description_rounded,
    };

Color _categoryColor(_ActionCategory category) => switch (category) {
      _ActionCategory.all => FilexaUi.primary,
      _ActionCategory.pdf => const Color(0xFFEF4444),
      _ActionCategory.images => const Color(0xFFEC4899),
      _ActionCategory.media => const Color(0xFF0EA5E9),
      _ActionCategory.code => const Color(0xFF8B5CF6),
      _ActionCategory.archives => const Color(0xFFF59E0B),
      _ActionCategory.apps => const Color(0xFF10B981),
      _ActionCategory.documents => const Color(0xFF64748B),
    };

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
