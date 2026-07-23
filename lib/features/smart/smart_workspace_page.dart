import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/file_item.dart';
import '../../core/providers/file_provider.dart';
import '../../theme/filexa_ui.dart';

class SmartWorkspacePage extends ConsumerStatefulWidget {
  const SmartWorkspacePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<SmartWorkspacePage> createState() => _SmartWorkspacePageState();
}

class _SmartWorkspacePageState extends ConsumerState<SmartWorkspacePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2) as int,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart workspace'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.cleaning_services_rounded), text: 'Cleaner'),
            Tab(icon: Icon(Icons.insights_rounded), text: 'Insights'),
            Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'Assistant'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CleanerTab(),
          _InsightsTab(),
          _AssistantTab(),
        ],
      ),
    );
  }
}

class _CleanerTab extends ConsumerWidget {
  const _CleanerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(filesProvider);
    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => FilexaEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Cleaner could not scan files',
        message: error.toString(),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(filesProvider),
      ),
      data: (files) {
        final duplicates = _duplicateCandidates(files);
        final oldDownloads = files
            .where((file) => DateTime.now().difference(file.modified).inDays >= 30)
            .toList()
          ..sort((a, b) => a.modified.compareTo(b.modified));
        final largeFiles = files.where((file) => file.size >= 100 * 1024 * 1024).toList()
          ..sort((a, b) => b.size.compareTo(a.size));
        final recoverable = _recoverableBytes(duplicates, oldDownloads);

        return RefreshIndicator(
          onRefresh: () async {
            await ref.refresh(filesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              _CleanerHero(
                recoverableBytes: recoverable,
                issueCount: duplicates.length + oldDownloads.length,
              ),
              const SizedBox(height: 24),
              const FilexaSectionTitle(title: 'Recommended cleanup'),
              const SizedBox(height: 10),
              _CleanerCategory(
                icon: Icons.copy_all_rounded,
                color: FilexaUi.violet,
                title: 'Duplicate candidates',
                subtitle: duplicates.isEmpty
                    ? 'No matching files found'
                    : '${duplicates.length} matching copies • ${_formatBytes(_duplicateWaste(duplicates))}',
                onTap: duplicates.isEmpty
                    ? null
                    : () => _showFileCandidates(
                          context,
                          ref,
                          title: 'Duplicate candidates',
                          message:
                              'These files have matching names and sizes. Review them before deleting.',
                          files: duplicates,
                        ),
              ),
              const SizedBox(height: 10),
              _CleanerCategory(
                icon: Icons.history_toggle_off_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Old downloads',
                subtitle: oldDownloads.isEmpty
                    ? 'No downloads older than 30 days'
                    : '${oldDownloads.length} files • ${_formatBytes(_sumBytes(oldDownloads))}',
                onTap: oldDownloads.isEmpty
                    ? null
                    : () => _showFileCandidates(
                          context,
                          ref,
                          title: 'Old downloads',
                          message: 'Files not modified for at least 30 days.',
                          files: oldDownloads,
                        ),
              ),
              const SizedBox(height: 10),
              _CleanerCategory(
                icon: Icons.sd_storage_rounded,
                color: const Color(0xFF0EA5E9),
                title: 'Large files',
                subtitle: largeFiles.isEmpty
                    ? 'No files larger than 100 MB'
                    : '${largeFiles.length} files • ${_formatBytes(_sumBytes(largeFiles))}',
                onTap: largeFiles.isEmpty
                    ? null
                    : () => _showFileCandidates(
                          context,
                          ref,
                          title: 'Large files',
                          message: 'Review large files before removing them.',
                          files: largeFiles,
                        ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: FilexaUi.cardDecoration(context, radius: 22, elevated: false),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, color: FilexaUi.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Filexa never deletes files automatically. Every cleanup action requires your confirmation.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CleanerHero extends StatelessWidget {
  const _CleanerHero({required this.recoverableBytes, required this.issueCount});

  final int recoverableBytes;
  final int issueCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: FilexaUi.heroGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_delete_outlined, color: Colors.white, size: 31),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Space you can review',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatBytes(recoverableBytes),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  issueCount == 0 ? 'Your Filexa folder looks clean' : '$issueCount items need review',
                  style: TextStyle(color: Colors.white.withValues(alpha: .78)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanerCategory extends StatelessWidget {
  const _CleanerCategory({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FilexaUi.surface(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                onTap == null ? Icons.check_circle_outline_rounded : Icons.chevron_right_rounded,
                color: onTap == null ? Colors.green : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightsTab extends ConsumerWidget {
  const _InsightsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(filesProvider);
    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => FilexaEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Insights are unavailable',
        message: error.toString(),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(filesProvider),
      ),
      data: (files) {
        final total = _sumBytes(files);
        final categories = _categoryBytes(files);
        final newest = [...files]..sort((a, b) => b.modified.compareTo(a.modified));
        final biggest = [...files]..sort((a, b) => b.size.compareTo(a.size));

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: FilexaUi.heroGradient,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.insights_rounded, color: Colors.white, size: 34),
                  const SizedBox(height: 18),
                  Text(
                    _formatBytes(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${files.length} downloaded files analyzed',
                    style: TextStyle(color: Colors.white.withValues(alpha: .78)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const FilexaSectionTitle(title: 'Storage mix'),
            const SizedBox(height: 10),
            ...categories.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InsightBar(
                  label: entry.key,
                  bytes: entry.value,
                  total: total,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InsightMetric(
                    icon: Icons.schedule_rounded,
                    label: 'Newest file',
                    value: newest.isEmpty ? '—' : _relativeDate(newest.first.modified),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InsightMetric(
                    icon: Icons.straighten_rounded,
                    label: 'Largest file',
                    value: biggest.isEmpty ? '—' : _formatBytes(biggest.first.size),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const FilexaSectionTitle(title: 'Largest downloads'),
            const SizedBox(height: 10),
            if (biggest.isEmpty)
              const FilexaEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No files yet',
                message: 'Your downloaded files will appear here.',
              )
            else
              ...biggest.take(5).map(
                    (file) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileSummaryTile(file: file),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _InsightBar extends StatelessWidget {
  const _InsightBar({required this.label, required this.bytes, required this.total});

  final String label;
  final int bytes;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : bytes / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: FilexaUi.cardDecoration(context, radius: 20, elevated: false),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(_formatBytes(bytes)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: value,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: FilexaUi.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FilexaUi.primary),
          const SizedBox(height: 12),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FileSummaryTile extends StatelessWidget {
  const _FileSummaryTile({required this.file});
  final FileItem file;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: FilexaUi.cardDecoration(context, radius: 20, elevated: false),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, color: FilexaUi.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Text(_formatBytes(file.size)),
        ],
      ),
    );
  }
}

class _AssistantTab extends ConsumerStatefulWidget {
  const _AssistantTab();

  @override
  ConsumerState<_AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends ConsumerState<_AssistantTab> {
  final _controller = TextEditingController();
  String? _answer;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask(List<FileItem> files, [String? prompt]) {
    final question = (prompt ?? _controller.text).trim();
    if (question.isEmpty) return;
    _controller.text = question;
    setState(() => _answer = _answerQuestion(question, files));
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(filesProvider);
    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => FilexaEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Assistant is unavailable',
        message: error.toString(),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(filesProvider),
      ),
      data: (files) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: FilexaUi.heroGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34),
                SizedBox(height: 18),
                Text(
                  'Filexa Assistant',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 6),
                Text(
                  'Ask about files stored in your Filexa download folder. Processing stays on your device.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _ask(files),
            decoration: InputDecoration(
              hintText: 'Ask about your files…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () => _ask(files),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PromptChip(label: 'Show my largest files', onTap: () => _ask(files, 'Show my largest files')),
              _PromptChip(label: 'How much storage is used?', onTap: () => _ask(files, 'How much storage is used?')),
              _PromptChip(label: 'Find old downloads', onTap: () => _ask(files, 'Find old downloads')),
              _PromptChip(label: 'Do I have duplicate files?', onTap: () => _ask(files, 'Do I have duplicate files?')),
            ],
          ),
          if (_answer != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: FilexaUi.cardDecoration(context, radius: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: FilexaUi.primary),
                  const SizedBox(width: 12),
                  Expanded(child: SelectableText(_answer!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: FilexaUi.cardDecoration(context, radius: 22, elevated: false),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: FilexaUi.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sprint 11 uses a private on-device assistant for file statistics. Online generative AI can be added later as an optional extension.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.bolt_rounded, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

Future<void> _showFileCandidates(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  required List<FileItem> files,
}) async {
  final selected = <String>{};
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .5,
        maxChildSize: .94,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(message, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  final checked = selected.contains(file.path);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (value) => setSheetState(() {
                      if (value ?? false) {
                        selected.add(file.path);
                      } else {
                        selected.remove(file.path);
                      }
                    }),
                    secondary: const Icon(Icons.insert_drive_file_rounded),
                    title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${_formatBytes(file.size)} • ${_relativeDate(file.modified)}'),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete ${selected.length} files?'),
                              content: const Text('This action cannot be undone.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          var deleted = 0;
                          for (final path in selected) {
                            try {
                              final file = File(path);
                              if (await file.exists()) {
                                await file.delete();
                                deleted++;
                              }
                            } on FileSystemException {
                              // Continue deleting the remaining selected files.
                            }
                          }
                          ref.invalidate(filesProvider);
                          if (context.mounted) Navigator.pop(context);
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text('$deleted files deleted')),
                            );
                          }
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(selected.isEmpty ? 'Select files to delete' : 'Delete ${selected.length} selected'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

List<FileItem> _duplicateCandidates(List<FileItem> files) {
  final groups = <String, List<FileItem>>{};
  for (final file in files) {
    final key = '${file.name.toLowerCase()}::${file.size}';
    groups.putIfAbsent(key, () => <FileItem>[]).add(file);
  }
  final results = <FileItem>[];
  for (final group in groups.values) {
    if (group.length > 1) {
      group.sort((a, b) => b.modified.compareTo(a.modified));
      results.addAll(group.skip(1));
    }
  }
  return results;
}

int _duplicateWaste(List<FileItem> duplicates) => _sumBytes(duplicates);

int _recoverableBytes(List<FileItem> duplicates, List<FileItem> oldDownloads) {
  final paths = <String>{};
  var total = 0;
  for (final file in [...duplicates, ...oldDownloads]) {
    if (paths.add(file.path)) total += file.size;
  }
  return total;
}

int _sumBytes(Iterable<FileItem> files) => files.fold<int>(0, (sum, file) => sum + file.size);

Map<String, int> _categoryBytes(List<FileItem> files) {
  final result = <String, int>{
    'Images': 0,
    'Videos': 0,
    'Audio': 0,
    'Documents': 0,
    'Archives': 0,
    'Other': 0,
  };
  for (final file in files) {
    final extension = _extension(file.name);
    final category = switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'svg' => 'Images',
      'mp4' || 'mkv' || 'mov' || 'avi' || 'webm' => 'Videos',
      'mp3' || 'm4a' || 'wav' || 'flac' || 'aac' => 'Audio',
      'pdf' || 'doc' || 'docx' || 'xls' || 'xlsx' || 'ppt' || 'pptx' || 'txt' || 'md' || 'csv' => 'Documents',
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => 'Archives',
      _ => 'Other',
    };
    result[category] = (result[category] ?? 0) + file.size;
  }
  return result;
}

String _answerQuestion(String question, List<FileItem> files) {
  final normalized = question.toLowerCase();
  final total = _sumBytes(files);
  final biggest = [...files]..sort((a, b) => b.size.compareTo(a.size));
  final old = files.where((file) => DateTime.now().difference(file.modified).inDays >= 30).toList();
  final duplicates = _duplicateCandidates(files);

  if (normalized.contains('large') || normalized.contains('largest') || normalized.contains('گەورە')) {
    if (biggest.isEmpty) return 'There are no downloaded files in your Filexa folder yet.';
    final lines = biggest.take(5).map((file) => '• ${file.name} — ${_formatBytes(file.size)}').join('\n');
    return 'Your largest downloaded files are:\n$lines';
  }
  if (normalized.contains('storage') || normalized.contains('space') || normalized.contains('قەبارە')) {
    return 'Filexa currently manages ${files.length} downloaded files using ${_formatBytes(total)}.';
  }
  if (normalized.contains('old') || normalized.contains('کۆن')) {
    return old.isEmpty
        ? 'I found no downloads older than 30 days.'
        : 'I found ${old.length} downloads older than 30 days, using ${_formatBytes(_sumBytes(old))}.';
  }
  if (normalized.contains('duplicate') || normalized.contains('دووبارە')) {
    return duplicates.isEmpty
        ? 'I found no duplicate candidates with matching names and sizes.'
        : 'I found ${duplicates.length} duplicate candidates that may free ${_formatBytes(_duplicateWaste(duplicates))}. Review them in Smart Cleaner before deleting anything.';
  }
  if (normalized.contains('pdf')) {
    final count = files.where((file) => _extension(file.name) == 'pdf').length;
    return 'You have $count PDF files in your Filexa download folder.';
  }
  if (normalized.contains('apk')) {
    final count = files.where((file) => _extension(file.name) == 'apk').length;
    return 'You have $count APK files in your Filexa download folder.';
  }
  return 'I can currently answer questions about storage usage, largest files, old downloads, duplicate candidates, PDFs and APK files. This assistant works locally on your device.';
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String _relativeDate(DateTime date) {
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 30) return '$days days ago';
  final months = (days / 30).floor();
  return months == 1 ? '1 month ago' : '$months months ago';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
