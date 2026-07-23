import 'package:flutter/material.dart';

import '../../core/download_manager.dart';
import '../../core/download_task.dart';
import '../../shared/new_download_dialog.dart';
import '../../theme/filexa_ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _newDownload(BuildContext context) async {
    final request = await showNewDownloadDialog(context);
    if (request == null || !context.mounted) return;
    await DownloadManager.instance.startDownload(
      url: request.url,
      fileName: request.fileName,
      folder: request.folder,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading ${request.fileName}…')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filexa', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            Text('Everything you download. In one place.', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          const SizedBox(width: 12),
        ],
      ),
      body: AnimatedBuilder(
        animation: DownloadManager.instance,
        builder: (context, _) {
          final tasks = DownloadManager.instance.tasks;
          final active = tasks.where((e) => e.isActive).toList();
          final completed = tasks.where((e) => e.status == DownloadStatus.completed).length;
          final downloadedBytes = tasks.fold<int>(0, (sum, e) => sum + e.receivedBytes);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              _HeroCard(onPressed: () => _newDownload(context), activeCount: active.length),
              const SizedBox(height: 22),
              const _SectionTitle('Quick actions'),
              const SizedBox(height: 12),
              _QuickActions(onNewDownload: () => _newDownload(context)),
              const SizedBox(height: 22),
              const _SectionTitle('Overview'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _MetricCard(icon: Icons.download_done_rounded, value: '$completed', label: 'Completed')),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(icon: Icons.data_usage_rounded, value: _formatBytes(downloadedBytes), label: 'Downloaded')),
              ]),
              const SizedBox(height: 12),
              _StorageCard(downloadedBytes: downloadedBytes),
              const SizedBox(height: 22),
              Row(children: [
                const Expanded(child: _SectionTitle('Recent downloads')),
                TextButton(onPressed: () {}, child: const Text('See all')),
              ]),
              const SizedBox(height: 8),
              _RecentList(tasks: tasks.take(3).toList()),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onPressed, required this.activeCount});
  final VoidCallback onPressed;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: FilexaUi.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF6750A4).withValues(alpha: .22), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.cloud_download_outlined, color: Colors.white, size: 30)),
          const Spacer(),
          if (activeCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)), child: Text('$activeCount active', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 22),
        const Text('Download anything,\nkeep everything organized.', style: TextStyle(color: Colors.white, fontSize: 24, height: 1.18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('Paste a direct link and Filexa will handle the rest.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: FilexaUi.deepPurple), icon: const Icon(Icons.add_link_rounded), label: const Text('New download')),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNewDownload});
  final VoidCallback onNewDownload;
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.link_rounded, 'Paste link', onNewDownload),
      (Icons.language_rounded, 'Browser', () {}),
      (Icons.folder_open_rounded, 'Files', () {}),
      (Icons.bar_chart_rounded, 'Insights', () {}),
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .82),
      itemBuilder: (context, i) {
        final theme = Theme.of(context);
        final dark = theme.brightness == Brightness.dark;
        final scheme = theme.colorScheme;
        return Material(
          color: dark ? const Color(0xFF211C2B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: items[i].$3,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: dark
                          ? scheme.primary.withValues(alpha: .20)
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      items[i].$1,
                      color: dark ? scheme.primaryContainer : scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.value, required this.label});
  final IconData icon; final String value; final String label;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(label, style: Theme.of(context).textTheme.bodySmall)]))])));
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.downloadedBytes});
  final int downloadedBytes;
  @override Widget build(BuildContext context) {
    const assumedCapacity = 5 * 1024 * 1024 * 1024;
    final value = (downloadedBytes / assumedCapacity).clamp(0.0, 1.0);
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(children: [Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.storage_rounded)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Filexa storage', style: TextStyle(fontWeight: FontWeight.w800)), Text('Downloaded files inside the app', style: TextStyle(fontSize: 12))])), Text(_formatBytes(downloadedBytes), style: const TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 16), LinearProgressIndicator(value: value, minHeight: 8, borderRadius: BorderRadius.circular(20)),
    ])));
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              Icon(
                Icons.download_done_rounded,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              const Text(
                'No downloads yet',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('Your newest files will appear here.'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: tasks.map((task) {
        final isCompleted = task.status == DownloadStatus.completed;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                isCompleted
                    ? Icons.check_rounded
                    : Icons.downloading_rounded,
              ),
            ),
            title: Text(
              task.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(task.status.name),
            trailing: Text(
              _formatBytes(task.receivedBytes),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }).toList(),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
