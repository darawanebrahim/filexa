import 'package:flutter/material.dart';

import '../../core/download_manager.dart';
import '../../core/download_task.dart';
import '../../shared/new_download_dialog.dart';
import '../../theme/filexa_ui.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  int _selectedFilter = 0;

  Future<void> _newDownload() async {
    final request = await showNewDownloadDialog(context);
    if (request == null || !mounted) return;

    await DownloadManager.instance.startDownload(
      url: request.url,
      fileName: request.fileName,
      folder: request.folder,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${request.fileName}…')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text(
          'Downloads',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Pause all',
            onPressed: DownloadManager.instance.pauseAll,
            icon: const Icon(Icons.pause_circle_outline_rounded),
          ),
          IconButton(
            tooltip: 'Resume all',
            onPressed: DownloadManager.instance.resumeAll,
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) {
              if (value == 'clearCompleted') {
                DownloadManager.instance.clearCompleted();
              } else if (value == 'clearFailed') {
                DownloadManager.instance.clearFailedAndCanceled();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clearCompleted',
                child: ListTile(
                  leading: Icon(Icons.done_all_rounded),
                  title: Text('Clear completed'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'clearFailed',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Clear failed'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedBuilder(
              animation: DownloadManager.instance,
              builder: (context, _) {
                final tasks = DownloadManager.instance.tasks;
                final running = tasks
                    .where((task) => task.status == DownloadStatus.downloading)
                    .length;
                final queued = DownloadManager.instance.queuedCount;
                final paused = DownloadManager.instance.pausedCount;
                final totalSpeed = tasks
                    .where((task) => task.status == DownloadStatus.downloading)
                    .fold<double>(0, (sum, task) => sum + task.speedBytesPerSecond);

                return _DownloadsHero(
                  running: running,
                  queued: queued,
                  paused: paused,
                  speed: totalSpeed,
                );
              },
            ),
            _DownloadFilters(
              selectedIndex: _selectedFilter,
              onSelected: (index) => setState(() => _selectedFilter = index),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: DownloadManager.instance,
                builder: (context, _) {
                  final tasks = _filteredTasks(
                    DownloadManager.instance.tasks,
                    _selectedFilter,
                  );
                  return _DownloadsContent(
                    tasks: tasks,
                    selectedFilter: _selectedFilter,
                    onNewDownload: _newDownload,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newDownload,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('New download'),
      ),
    );
  }

  List<DownloadTask> _filteredTasks(List<DownloadTask> tasks, int filter) {
    return switch (filter) {
      1 => tasks.where((task) => task.isActive).toList(),
      2 => tasks.where((task) => task.status == DownloadStatus.paused).toList(),
      3 => tasks
          .where((task) => task.status == DownloadStatus.completed)
          .toList(),
      4 => tasks
          .where((task) =>
              task.status == DownloadStatus.failed ||
              task.status == DownloadStatus.canceled)
          .toList(),
      _ => tasks,
    };
  }
}

class _DownloadsHero extends StatelessWidget {
  const _DownloadsHero({
    required this.running,
    required this.queued,
    required this.paused,
    required this.speed,
  });

  final int running;
  final int queued;
  final int paused;
  final double speed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: FilexaUi.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: FilexaUi.primary.withValues(alpha: .22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.download_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Downloads',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Fast, organized and under control',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (running + queued > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${running + queued} active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroStat(label: 'Running', value: '$running'),
              const SizedBox(width: 10),
              _HeroStat(label: 'Queued', value: '$queued'),
              const SizedBox(width: 10),
              _HeroStat(label: 'Paused', value: '$paused'),
              const SizedBox(width: 10),
              _HeroStat(
                label: 'Speed',
                value: speed > 0 ? '${_formatBytes(speed.round())}/s' : '0 B/s',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadsContent extends StatelessWidget {
  const _DownloadsContent({
    required this.tasks,
    required this.selectedFilter,
    required this.onNewDownload,
  });

  final List<DownloadTask> tasks;
  final int selectedFilter;
  final VoidCallback onNewDownload;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _EmptyDownloads(
        selectedFilter: selectedFilter,
        onNewDownload: onNewDownload,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _DownloadTaskCard(task: tasks[index]),
    );
  }
}

class _DownloadFilters extends StatelessWidget {
  const _DownloadFilters({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const filters = ['All', 'Active', 'Paused', 'Completed', 'Failed'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ChoiceChip(
          label: Text(filters[index]),
          selected: selectedIndex == index,
          onSelected: (_) => onSelected(index),
        ),
      ),
    );
  }
}

class _DownloadTaskCard extends StatelessWidget {
  const _DownloadTaskCard({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = task.totalBytes > 0 ? task.progress.clamp(0.0, 1.0) : null;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _showTaskDetails(context, task),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: FilexaUi.cardDecoration(context, radius: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FileIcon(status: task.status),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _statusText(task),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: task.status == DownloadStatus.failed
                              ? colors.error
                              : colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _TaskMenu(task: task),
              ],
            ),
            if (task.isActive || task.canResume) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: colors.primaryContainer.withValues(alpha: .55),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaPill(
                    icon: Icons.pie_chart_outline_rounded,
                    text: task.totalBytes > 0
                        ? '${(task.progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                        : _formatBytes(task.receivedBytes),
                  ),
                  _MetaPill(
                    icon: Icons.speed_rounded,
                    text: task.speedBytesPerSecond > 0
                        ? '${_formatBytes(task.speedBytesPerSecond.round())}/s'
                        : 'Starting…',
                  ),
                  if (task.estimatedRemaining != null)
                    _MetaPill(
                      icon: Icons.schedule_rounded,
                      text: '${_formatDuration(task.estimatedRemaining!)} left',
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (task.canPause)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () =>
                            DownloadManager.instance.pauseDownload(task.id),
                        icon: const Icon(Icons.pause_rounded),
                        label: const Text('Pause'),
                      ),
                    )
                  else if (task.canResume)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            DownloadManager.instance.resumeDownload(task.id),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Resume'),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          DownloadManager.instance.cancelDownload(task.id),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FilexaUi.softSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

Future<void> _showTaskDetails(BuildContext context, DownloadTask task) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FileIcon(status: task.status),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(_statusText(task), style: TextStyle(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _DetailRow(label: 'Status', value: _statusName(task.status)),
            _DetailRow(label: 'Downloaded', value: _formatBytes(task.receivedBytes)),
            _DetailRow(
              label: 'Total size',
              value: task.totalBytes > 0 ? _formatBytes(task.totalBytes) : 'Unknown',
            ),
            _DetailRow(
              label: 'Speed',
              value: task.speedBytesPerSecond > 0
                  ? '${_formatBytes(task.speedBytesPerSecond.round())}/s'
                  : '—',
            ),
            _DetailRow(label: 'Folder', value: task.folder),
            if (task.savedPath != null)
              _DetailRow(label: 'Path', value: task.savedPath!),
            const SizedBox(height: 18),
            Row(
              children: [
                if (task.canPause)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        DownloadManager.instance.pauseDownload(task.id);
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pause'),
                    ),
                  )
                else if (task.canResume)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        DownloadManager.instance.resumeDownload(task.id);
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Resume'),
                    ),
                  )
                else if (task.status == DownloadStatus.failed ||
                    task.status == DownloadStatus.canceled)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        DownloadManager.instance.retryDownload(task.id);
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                if (task.canPause || task.canResume ||
                    task.status == DownloadStatus.failed ||
                    task.status == DownloadStatus.canceled)
                  const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (task.isActive || task.canResume) {
                        DownloadManager.instance.cancelDownload(task.id);
                      } else {
                        DownloadManager.instance.removeTask(task.id);
                      }
                      Navigator.pop(sheetContext);
                    },
                    icon: Icon(task.isActive || task.canResume
                        ? Icons.close_rounded
                        : Icons.delete_outline_rounded),
                    label: Text(task.isActive || task.canResume ? 'Cancel' : 'Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TaskMenu extends StatelessWidget {
  const _TaskMenu({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'pause':
            DownloadManager.instance.pauseDownload(task.id);
            return;
          case 'resume':
            DownloadManager.instance.resumeDownload(task.id);
            return;
          case 'cancel':
            DownloadManager.instance.cancelDownload(task.id);
            return;
          case 'retry':
            DownloadManager.instance.retryDownload(task.id);
            return;
          case 'remove':
            DownloadManager.instance.removeTask(task.id);
            return;
        }
      },
      itemBuilder: (context) => [
        if (task.canPause)
          const PopupMenuItem(value: 'pause', child: Text('Pause')),
        if (task.canResume)
          const PopupMenuItem(value: 'resume', child: Text('Resume')),
        if (task.isActive || task.canResume)
          const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
        if (task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.canceled)
          const PopupMenuItem(value: 'retry', child: Text('Retry')),
        if (!task.isActive)
          const PopupMenuItem(value: 'remove', child: Text('Remove from list')),
      ],
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, foreground, background) = switch (status) {
      DownloadStatus.completed => (
          Icons.check_rounded,
          Colors.green.shade700,
          Colors.green.withValues(alpha: .13),
        ),
      DownloadStatus.failed => (
          Icons.error_outline_rounded,
          colors.error,
          colors.errorContainer,
        ),
      DownloadStatus.canceled => (
          Icons.block_rounded,
          colors.onSurfaceVariant,
          colors.surfaceContainerHighest,
        ),
      DownloadStatus.paused => (
          Icons.pause_rounded,
          colors.primary,
          colors.primaryContainer,
        ),
      _ => (
          Icons.download_rounded,
          colors.primary,
          colors.primaryContainer,
        ),
    };

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: foreground, size: 29),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({
    required this.selectedFilter,
    required this.onNewDownload,
  });

  final int selectedFilter;
  final VoidCallback onNewDownload;

  @override
  Widget build(BuildContext context) {
    final title = switch (selectedFilter) {
      1 => 'No active downloads',
      2 => 'No paused downloads',
      3 => 'No completed downloads',
      4 => 'No failed downloads',
      _ => 'No downloads yet',
    };
    final message = switch (selectedFilter) {
      1 => 'Running and queued downloads will appear here.',
      2 => 'Downloads you pause will stay ready to resume here.',
      3 => 'Completed files will appear here.',
      4 => 'Failed and canceled downloads will appear here.',
      _ => 'Add a direct file link to start your first download.',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 110),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
          decoration: FilexaUi.cardDecoration(context, radius: 24),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: FilexaUi.softSurface(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.download_done_rounded,
                    size: 38, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (selectedFilter == 0) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onNewDownload,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('New download'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _statusText(DownloadTask task) {
  return switch (task.status) {
    DownloadStatus.queued => 'Waiting to start…',
    DownloadStatus.downloading => task.totalBytes > 0
        ? '${_formatBytes(task.receivedBytes)} of ${_formatBytes(task.totalBytes)}'
        : '${_formatBytes(task.receivedBytes)} downloaded',
    DownloadStatus.paused => task.totalBytes > 0
        ? 'Paused • ${_formatBytes(task.receivedBytes)} of ${_formatBytes(task.totalBytes)}'
        : 'Paused • ${_formatBytes(task.receivedBytes)} downloaded',
    DownloadStatus.completed => 'Completed • ${_formatBytes(task.receivedBytes)}',
    DownloadStatus.failed => task.errorMessage ?? 'Download failed.',
    DownloadStatus.canceled => 'Canceled',
  };
}

String _statusName(DownloadStatus status) {
  return switch (status) {
    DownloadStatus.queued => 'Queued',
    DownloadStatus.downloading => 'Downloading',
    DownloadStatus.paused => 'Paused',
    DownloadStatus.completed => 'Completed',
    DownloadStatus.failed => 'Failed',
    DownloadStatus.canceled => 'Canceled',
  };
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}

String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours}h ${minutes}m';
  }
  if (duration.inMinutes > 0) {
    final seconds = duration.inSeconds.remainder(60);
    return '${duration.inMinutes}m ${seconds}s';
  }
  return '${duration.inSeconds.clamp(0, 59)}s';
}
