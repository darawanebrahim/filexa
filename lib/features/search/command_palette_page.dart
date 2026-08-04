import 'package:flutter/material.dart';

import '../../core/download_manager.dart';
import '../../shared/new_download_dialog.dart';
import '../../theme/filexa_ui.dart';
import '../documents/document_center_page.dart';
import '../smart/smart_workspace_page.dart';
import '../storage/storage_analyzer_page.dart';
import 'global_search_page.dart';

class CommandPalettePage extends StatefulWidget {
  const CommandPalettePage({super.key});

  @override
  State<CommandPalettePage> createState() => _CommandPalettePageState();
}

class _CommandPalettePageState extends State<CommandPalettePage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commands = _commands(context)
        .where((command) => command.searchText.contains(_query.toLowerCase()))
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Command palette')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.terminal_rounded),
                  hintText: 'Search actions: PDF, download, storage…',
                ),
              ),
            ),
            Expanded(
              child: commands.isEmpty
                  ? const Center(child: Text('No matching action.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: commands.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final command = commands[index];
                        return Container(
                          decoration: FilexaUi.cardDecoration(
                            context,
                            radius: 20,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  command.color.withValues(alpha: .14),
                              child: Icon(command.icon, color: command.color),
                            ),
                            title: Text(
                              command.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(command.subtitle),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: command.onTap,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_CommandAction> _commands(BuildContext context) => [
        _CommandAction(
          icon: Icons.download_rounded,
          color: FilexaUi.primary,
          title: 'New download',
          subtitle: 'Analyze and download a direct file link',
          keywords: 'link clipboard browser internet',
          onTap: () => _newDownload(context),
        ),
        _CommandAction(
          icon: Icons.search_rounded,
          color: const Color(0xFF0EA5E9),
          title: 'Search everything',
          subtitle: 'Search files and downloaded content',
          keywords: 'find file global universal',
          onTap: () => _push(context, const GlobalSearchPage()),
        ),
        _CommandAction(
          icon: Icons.picture_as_pdf_rounded,
          color: const Color(0xFFEF4444),
          title: 'Document center',
          subtitle: 'Open PDF, Office, HTML and code files',
          keywords: 'pdf word excel html code text',
          onTap: () => _push(context, const DocumentCenterPage()),
        ),
        _CommandAction(
          icon: Icons.pie_chart_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'Storage analyzer',
          subtitle: 'Review file categories and large files',
          keywords: 'storage disk space large cleaner',
          onTap: () => _push(context, const StorageAnalyzerPage()),
        ),
        _CommandAction(
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFFEC4899),
          title: 'Smart workspace',
          subtitle: 'Cleaner, local assistant and smart tools',
          keywords: 'assistant cleaner smart tools',
          onTap: () => _push(context, const SmartWorkspacePage()),
        ),
      ];

  Future<void> _newDownload(BuildContext context) async {
    final request = await showNewDownloadDialog(context);
    if (request == null || !context.mounted) return;
    await DownloadManager.instance.startDownload(
      url: request.url,
      fileName: request.fileName,
      folder: request.folder,
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _CommandAction {
  const _CommandAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String keywords;
  final VoidCallback onTap;

  String get searchText => '$title $subtitle $keywords'.toLowerCase();
}
