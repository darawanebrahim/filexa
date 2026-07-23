import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/file_item.dart';
import '../../core/providers/file_provider.dart';
import '../../theme/filexa_ui.dart';

class StorageAnalyzerPage extends ConsumerWidget {
  const StorageAnalyzerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(filesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Storage analyzer')),
      body: filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => FilexaEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not analyze storage',
          message: error.toString(),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(filesProvider),
        ),
        data: (files) {
          final groups = _buildGroups(files);
          final total = files.fold<int>(0, (sum, item) => sum + item.size);
          final biggest = [...files]..sort((a, b) => b.size.compareTo(a.size));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
                    const Icon(Icons.donut_large_rounded,
                        color: Colors.white, size: 34),
                    const SizedBox(height: 22),
                    Text(_formatBytes(total),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${files.length} Filexa files analyzed',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .78))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const FilexaSectionTitle(title: 'By category'),
              const SizedBox(height: 10),
              ...groups.map((group) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CategoryTile(group: group, total: total),
                  )),
              const SizedBox(height: 16),
              const FilexaSectionTitle(title: 'Largest files'),
              const SizedBox(height: 10),
              if (biggest.isEmpty)
                const FilexaEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No files yet',
                  message: 'Downloaded files will appear here.',
                )
              else
                ...biggest.take(5).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: FilexaUi.surface(context),
                        borderRadius: BorderRadius.circular(20),
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file_rounded,
                              color: FilexaUi.primary),
                          title: Text(item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(_formatBytes(item.size)),
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _StorageGroup {
  const _StorageGroup(this.name, this.icon, this.bytes, this.color);
  final String name;
  final IconData icon;
  final int bytes;
  final Color color;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.group, required this.total});
  final _StorageGroup group;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : group.bytes / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: FilexaUi.cardDecoration(context, radius: 20, elevated: false),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: group.color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(group.icon, color: group.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(group.name,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text(_formatBytes(group.bytes)),
                ]),
                const SizedBox(height: 9),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(20),
                  color: group.color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<_StorageGroup> _buildGroups(List<FileItem> files) {
  int images = 0, videos = 0, audio = 0, documents = 0, archives = 0, other = 0;
  for (final file in files) {
    final ext = _extension(file.name);
    if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'}.contains(ext)) {
      images += file.size;
    } else if ({'mp4', 'mkv', 'mov', 'avi', 'webm'}.contains(ext)) {
      videos += file.size;
    } else if ({'mp3', 'm4a', 'wav', 'flac', 'aac'}.contains(ext)) {
      audio += file.size;
    } else if ({'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'}.contains(ext)) {
      documents += file.size;
    } else if ({'zip', 'rar', '7z', 'tar', 'gz'}.contains(ext)) {
      archives += file.size;
    } else {
      other += file.size;
    }
  }
  return [
    _StorageGroup('Images', Icons.image_rounded, images, FilexaUi.violet),
    _StorageGroup('Videos', Icons.movie_rounded, videos, FilexaUi.indigo),
    _StorageGroup('Audio', Icons.music_note_rounded, audio, const Color(0xFFEC4899)),
    _StorageGroup('Documents', Icons.description_rounded, documents, const Color(0xFFF97316)),
    _StorageGroup('Archives', Icons.archive_rounded, archives, FilexaUi.warning),
    _StorageGroup('Other', Icons.more_horiz_rounded, other, const Color(0xFF64748B)),
  ];
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
