import 'package:flutter/material.dart';

import '../../core/download_manager.dart';
import '../../core/download_task.dart';
import '../../shared/new_download_dialog.dart';
import '../../theme/filexa_ui.dart';
import '../documents/pdf_studio_page.dart';
import '../documents/office_studio_page.dart';
import '../actions/filexa_action_center_page.dart';
import '../search/global_search_page.dart';
import '../search/command_palette_page.dart';
import '../storage/storage_analyzer_page.dart';
import '../smart/smart_workspace_page.dart';

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
            Text(
              'Hi, Darawan 👋',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            Text(
              'Your smart file workspace',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AnimatedBuilder(
        animation: DownloadManager.instance,
        builder: (context, _) {
          final tasks = DownloadManager.instance.tasks;
          final active = tasks.where((task) => task.isActive).length;
          final completed = tasks
              .where((task) => task.status == DownloadStatus.completed)
              .length;
          final downloadedBytes = tasks.fold<int>(
            0,
            (sum, task) => sum + task.receivedBytes,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              _SearchLauncher(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GlobalSearchPage(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _StorageHero(
                downloadedBytes: downloadedBytes,
                completed: completed,
                active: active,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StorageAnalyzerPage(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const FilexaSectionTitle(title: 'Quick actions'),
              const SizedBox(height: 12),
              _QuickActions(
                onNewDownload: () => _newDownload(context),
                onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GlobalSearchPage(),
                  ),
                ),
                onStorage: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StorageAnalyzerPage(),
                  ),
                ),
                onDocuments: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PdfStudioPage(),
                  ),
                ),
                onOffice: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OfficeStudioPage(),
                  ),
                ),
                onSmartTools: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SmartWorkspacePage(),
                  ),
                ),
                onCommands: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CommandPalettePage(),
                  ),
                ),
                onActionCenter: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FilexaActionCenterPage(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const FilexaSectionTitle(title: 'Smart overview'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.download_done_rounded,
                      value: '$completed',
                      label: 'Completed',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.downloading_rounded,
                      value: '$active',
                      label: 'Active',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilexaSectionTitle(
                title: 'Recent downloads',
                actionLabel: tasks.isEmpty ? null : 'View all',
                onAction: () {},
              ),
              const SizedBox(height: 10),
              if (tasks.isEmpty)
                const _CompactEmpty()
              else
                ...tasks
                    .take(4)
                    .map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentDownload(task: task),
                      ),
                    ),
              const SizedBox(height: 14),
              const _SmartSuggestion(),
            ],
          );
        },
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FilexaUi.surface(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              const Icon(Icons.search_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search files, downloads and content',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Icon(Icons.mic_none_rounded, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageHero extends StatelessWidget {
  const _StorageHero({
    required this.downloadedBytes,
    required this.completed,
    required this.active,
    required this.onTap,
  });

  final int downloadedBytes;
  final int completed;
  final int active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: FilexaUi.heroGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: FilexaUi.primary.withValues(alpha: .23),
            blurRadius: 30,
            offset: const Offset(0, 15),
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
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: .35)),
                ),
                child: const Text('Analyze'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Everything you download.\nOne beautiful place.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatBytes(downloadedBytes)} managed • $completed completed • $active active',
            style: TextStyle(color: Colors.white.withValues(alpha: .78)),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNewDownload,
    required this.onSearch,
    required this.onStorage,
    required this.onDocuments,
    required this.onOffice,
    required this.onSmartTools,
    required this.onCommands,
    required this.onActionCenter,
  });

  final VoidCallback onNewDownload;
  final VoidCallback onSearch;
  final VoidCallback onStorage;
  final VoidCallback onDocuments;
  final VoidCallback onOffice;
  final VoidCallback onSmartTools;
  final VoidCallback onCommands;
  final VoidCallback onActionCenter;

  @override
  Widget build(BuildContext context) {
    final actions =
        <({IconData icon, String label, Color color, VoidCallback onTap})>[
          (
            icon: Icons.add_link_rounded,
            label: 'New download',
            color: FilexaUi.primary,
            onTap: onNewDownload,
          ),
          (
            icon: Icons.manage_search_rounded,
            label: 'Search',
            color: FilexaUi.indigo,
            onTap: onSearch,
          ),
          (
            icon: Icons.pie_chart_rounded,
            label: 'Storage',
            color: const Color(0xFF0EA5E9),
            onTap: onStorage,
          ),
          (
            icon: Icons.picture_as_pdf_rounded,
            label: 'PDF center',
            color: const Color(0xFFEF4444),
            onTap: onDocuments,
          ),
          (
            icon: Icons.business_center_rounded,
            label: 'Office Studio',
            color: const Color(0xFF2563EB),
            onTap: onOffice,
          ),
          (
            icon: Icons.cleaning_services_rounded,
            label: 'Smart cleaner',
            color: const Color(0xFF10B981),
            onTap: onSmartTools,
          ),
          (
            icon: Icons.auto_awesome_rounded,
            label: 'Commands',
            color: const Color(0xFFEC4899),
            onTap: onCommands,
          ),
          (
            icon: Icons.bolt_rounded,
            label: 'Action center',
            color: const Color(0xFFF59E0B),
            onTap: onActionCenter,
          ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final columns = compact ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: compact ? 96 : 106,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            final scheme = Theme.of(context).colorScheme;
            return Container(
              decoration: FilexaUi.cardDecoration(
                context,
                radius: 22,
                elevated: false,
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: action.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: action.color.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            action.icon,
                            color: action.color,
                            size: 23,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Flexible(
                          child: Text(
                            action.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 10.5,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: FilexaUi.cardDecoration(context, radius: 22),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: FilexaUi.softSurface(context),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: FilexaUi.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentDownload extends StatelessWidget {
  const _RecentDownload({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: FilexaUi.cardDecoration(context, radius: 20, elevated: false),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FilexaUi.softSurface(context),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_statusIcon(task.status), color: FilexaUi.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(task.status),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (task.isActive) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: task.progress.clamp(0, 1),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${(task.progress * 100).clamp(0, 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: FilexaUi.cardDecoration(context, radius: 22, elevated: false),
      child: const Row(
        children: [
          Icon(Icons.download_for_offline_outlined, color: FilexaUi.primary),
          SizedBox(width: 14),
          Expanded(child: Text('Your newest downloads will appear here.')),
        ],
      ),
    );
  }
}

class _SmartSuggestion extends StatelessWidget {
  const _SmartSuggestion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FilexaUi.softSurface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: FilexaUi.warning),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart suggestion',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Use Storage Analyzer to discover your largest downloaded files.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _statusIcon(DownloadStatus status) => switch (status) {
  DownloadStatus.completed => Icons.check_circle_rounded,
  DownloadStatus.downloading => Icons.downloading_rounded,
  DownloadStatus.paused => Icons.pause_circle_rounded,
  DownloadStatus.failed => Icons.error_rounded,
  DownloadStatus.canceled => Icons.cancel_rounded,
  DownloadStatus.queued => Icons.schedule_rounded,
};

String _statusLabel(DownloadStatus status) => switch (status) {
  DownloadStatus.completed => 'Completed',
  DownloadStatus.downloading => 'Downloading',
  DownloadStatus.paused => 'Paused',
  DownloadStatus.failed => 'Failed',
  DownloadStatus.canceled => 'Canceled',
  DownloadStatus.queued => 'Queued',
};

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
