import 'package:flutter/material.dart';

import '../../core/download_manager.dart';
import '../../core/download_task.dart';
import '../../shared/new_download_dialog.dart';
import '../../theme/filexa_ui.dart';

enum _DownloadSort { newest, oldest, name, size }

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  int _selectedFilter = 0;
  String _query = '';
  _DownloadSort _sort = _DownloadSort.newest;
  bool _compactView = false;

  Future<void> _newDownload() async {
    final request = await showNewDownloadDialog(context);
    if (request == null || !mounted) return;

    var fileName = request.fileName;
    if (DownloadManager.instance.hasDuplicateName(fileName)) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Duplicate download'),
          content: Text('A download named “$fileName” already exists.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'skip'),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'rename'),
              child: const Text('Download a copy'),
            ),
          ],
        ),
      );
      if (action != 'rename' || !mounted) return;
      fileName = _copyName(fileName);
    }

    await DownloadManager.instance.startDownload(
      url: request.url,
      fileName: fileName,
      folder: request.folder,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading $fileName…')),
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
        child: AnimatedBuilder(
          animation: DownloadManager.instance,
          builder: (context, _) {
            final allTasks = DownloadManager.instance.tasks;
            final running = allTasks
                .where((task) => task.status == DownloadStatus.downloading)
                .length;
            final queued = DownloadManager.instance.queuedCount;
            final paused = DownloadManager.instance.pausedCount;
            final totalSpeed = allTasks
                .where((task) => task.status == DownloadStatus.downloading)
                .fold<double>(
                  0,
                  (sum, task) => sum + task.speedBytesPerSecond,
                );
            final tasks = _organizedTasks(allTasks, _selectedFilter);

            return Scrollbar(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  _DownloadsHero(
                    running: running,
                    queued: queued,
                    paused: paused,
                    speed: totalSpeed,
                  ),
                  _DownloadFilters(
                    selectedIndex: _selectedFilter,
                    onSelected: (index) =>
                        setState(() => _selectedFilter = index),
                  ),
                  _DownloadsToolbar(
                    query: _query,
                    sort: _sort,
                    compactView: _compactView,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onSortChanged: (value) => setState(() => _sort = value),
                    onToggleView: () =>
                        setState(() => _compactView = !_compactView),
                  ),
                  _DownloadsContent(
                    tasks: tasks,
                    selectedFilter: _selectedFilter,
                    query: _query,
                    compactView: _compactView,
                    onNewDownload: _newDownload,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newDownload,
        tooltip: 'New download',
        child: const Icon(Icons.add_link_rounded),
      ),
    );
  }

  List<DownloadTask> _organizedTasks(List<DownloadTask> tasks, int filter) {
    final filtered = switch (filter) {
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

    final query = _query.trim().toLowerCase();
    final searched = query.isEmpty
        ? List<DownloadTask>.from(filtered)
        : filtered.where((task) {
            return task.fileName.toLowerCase().contains(query) ||
                task.url.toLowerCase().contains(query) ||
                task.folder.toLowerCase().contains(query);
          }).toList();

    searched.sort((a, b) {
      return switch (_sort) {
        _DownloadSort.newest => b.createdAt.compareTo(a.createdAt),
        _DownloadSort.oldest => a.createdAt.compareTo(b.createdAt),
        _DownloadSort.name =>
          a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        _DownloadSort.size => b.totalBytes.compareTo(a.totalBytes),
      };
    });
    return searched;
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
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5534C9), Color(0xFF7C4DFF), Color(0xFFA65BFF)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D4AFF).withValues(alpha: .24),
            blurRadius: 30,
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .17), borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.downloading_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Download center', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Reliable queue, clear progress, full control', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: width, child: _HeroStat(label: 'Running', value: '$running', icon: Icons.bolt_rounded)),
                  SizedBox(width: width, child: _HeroStat(label: 'Queued', value: '$queued', icon: Icons.schedule_rounded)),
                  SizedBox(width: width, child: _HeroStat(label: 'Paused', value: '$paused', icon: Icons.pause_rounded)),
                  SizedBox(width: width, child: _HeroStat(label: 'Current speed', value: speed > 0 ? '${_formatBytes(speed.round())}/s' : '0 B/s', icon: Icons.speed_rounded)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsToolbar extends StatelessWidget {
  const _DownloadsToolbar({
    required this.query,
    required this.sort,
    required this.compactView,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onToggleView,
  });

  final String query;
  final _DownloadSort sort;
  final bool compactView;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_DownloadSort> onSortChanged;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search downloads',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => onQueryChanged(''),
                        icon: const Icon(Icons.close_rounded),
                      ),
                isDense: true,
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<_DownloadSort>(
            tooltip: 'Sort downloads',
            initialValue: sort,
            onSelected: onSortChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: _DownloadSort.newest, child: Text('Newest first')),
              PopupMenuItem(value: _DownloadSort.oldest, child: Text('Oldest first')),
              PopupMenuItem(value: _DownloadSort.name, child: Text('File name')),
              PopupMenuItem(value: _DownloadSort.size, child: Text('File size')),
            ],
            child: _ToolbarButton(
              icon: Icons.sort_rounded,
              tooltip: 'Sort downloads',
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggleView,
            child: _ToolbarButton(
              icon: compactView ? Icons.view_agenda_outlined : Icons.view_list_rounded,
              tooltip: compactView ? 'Comfortable view' : 'Compact view',
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.tooltip});
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Icon(icon, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _DownloadsContent extends StatelessWidget {
  const _DownloadsContent({
    required this.tasks,
    required this.selectedFilter,
    required this.query,
    required this.compactView,
    required this.onNewDownload,
  });

  final List<DownloadTask> tasks;
  final int selectedFilter;
  final String query;
  final bool compactView;
  final VoidCallback onNewDownload;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _EmptyDownloads(
        selectedFilter: selectedFilter,
        query: query,
        compactView: compactView,
        onNewDownload: onNewDownload,
      );
    }

    final rows = <Object>[];
    String? currentGroup;
    for (final task in tasks) {
      final group = _downloadDateGroup(task.createdAt);
      if (group != currentGroup) {
        rows.add(group);
        currentGroup = group;
      }
      rows.add(task);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(rows.length, (index) {
          final row = rows[index];
          if (row is String) {
            return Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : 10,
                bottom: 10,
              ),
              child: Text(
                row,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _DownloadTaskCard(
              task: row as DownloadTask,
              compact: compactView,
            ),
          );
        }),
      ),
    );
  }
}

class _DownloadFilters extends StatelessWidget {
  const _DownloadFilters({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const filters = ['All', 'Active', 'Paused', 'Done', 'Failed'];
  static const icons = [Icons.grid_view_rounded, Icons.downloading_rounded, Icons.pause_rounded, Icons.check_circle_outline_rounded, Icons.error_outline_rounded];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return Material(
            color: selected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () => onSelected(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: selected ? scheme.primary.withValues(alpha: .25) : scheme.outlineVariant.withValues(alpha: .45)),
                ),
                child: Row(
                  children: [
                    Icon(icons[index], size: 17, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                    const SizedBox(width: 7),
                    Text(filters[index], style: TextStyle(fontWeight: FontWeight.w800, color: selected ? scheme.primary : scheme.onSurfaceVariant)),
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

class _DownloadTaskCard extends StatelessWidget {
  const _DownloadTaskCard({required this.task, required this.compact});

  final DownloadTask task;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = task.totalBytes > 0 ? task.progress.clamp(0.0, 1.0) : null;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showTaskDetails(context, task),
      child: Ink(
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: FilexaUi.cardDecoration(context, radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FileIcon(status: task.status, compact: compact),
                SizedBox(width: compact ? 10 : 14),
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
                      Row(
                        children: [
                          _PriorityBadge(priority: task.priority),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _TaskMenu(task: task),
              ],
            ),
            if (task.isActive || task.canResume) ...[
              SizedBox(height: compact ? 12 : 18),
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
            _DetailRow(label: 'Priority', value: _priorityLabel(task.priority)),
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
          case 'priorityHigh':
            DownloadManager.instance.setPriority(task.id, DownloadPriority.high);
            return;
          case 'priorityNormal':
            DownloadManager.instance.setPriority(task.id, DownloadPriority.normal);
            return;
          case 'priorityLow':
            DownloadManager.instance.setPriority(task.id, DownloadPriority.low);
            return;
          case 'remove':
            DownloadManager.instance.removeTask(task.id);
            return;
        }
      },
      itemBuilder: (context) => [
        if (task.status != DownloadStatus.completed)
          const PopupMenuItem(value: 'priorityHigh', child: Text('High priority')),
        if (task.status != DownloadStatus.completed)
          const PopupMenuItem(value: 'priorityNormal', child: Text('Normal priority')),
        if (task.status != DownloadStatus.completed)
          const PopupMenuItem(value: 'priorityLow', child: Text('Low priority')),
        if (task.status != DownloadStatus.completed)
          const PopupMenuDivider(),
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
  const _FileIcon({required this.status, this.compact = false});

  final DownloadStatus status;
  final bool compact;

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
      width: compact ? 46 : 56,
      height: compact ? 46 : 56,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: foreground, size: compact ? 24 : 29),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({
    required this.selectedFilter,
    required this.query,
    required this.compactView,
    required this.onNewDownload,
  });

  final int selectedFilter;
  final String query;
  final bool compactView;
  final VoidCallback onNewDownload;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    final title = hasQuery ? 'No matching downloads' : switch (selectedFilter) {
      1 => 'No active downloads',
      2 => 'No paused downloads',
      3 => 'No completed downloads',
      4 => 'No failed downloads',
      _ => 'No downloads yet',
    };
    final message = hasQuery
        ? 'Try another file name, folder, or web address.'
        : switch (selectedFilter) {
      1 => 'Running and queued downloads will appear here.',
      2 => 'Downloads you pause will stay ready to resume here.',
      3 => 'Completed files will appear here.',
      4 => 'Failed and canceled downloads will appear here.',
      _ => 'Add a direct file link to start your first download.',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(20, compactView ? 24 : 42, 20, 0),
      child: Container(
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
              if (selectedFilter == 0 && !hasQuery) ...[
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

String _downloadDateGroup(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final value = DateTime(date.year, date.month, date.day);
  final difference = today.difference(value).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference < 7) return 'Earlier this week';
  if (date.year == now.year && date.month == now.month) {
    return 'Earlier this month';
  }
  return 'Older downloads';
}


class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final DownloadPriority priority;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (priority) {
      DownloadPriority.high => ('High', Icons.keyboard_double_arrow_up_rounded, colors.error),
      DownloadPriority.normal => ('Normal', Icons.remove_rounded, colors.primary),
      DownloadPriority.low => ('Low', Icons.keyboard_double_arrow_down_rounded, colors.tertiary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

String _priorityLabel(DownloadPriority priority) => switch (priority) {
      DownloadPriority.high => 'High',
      DownloadPriority.normal => 'Normal',
      DownloadPriority.low => 'Low',
    };

String _copyName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0) return '$fileName copy';
  return '${fileName.substring(0, dot)} copy${fileName.substring(dot)}';
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
