import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../theme/filexa_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _downloadNotifications = true;
  bool _clipboardDetection = true;
  bool _wifiOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          const FilexaPageHeader(
            title: 'Make Filexa yours',
            subtitle: 'One design language across every screen',
            icon: Icons.tune_rounded,
          ),
          _group(
            context,
            title: 'Appearance',
            children: [
              _SettingTile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: _themeLabel(AppController.themeMode.value),
                onTap: () => _showThemePicker(AppController.themeMode.value),
              ),
              const _SettingTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'English • Kurdish Sorani coming next',
              ),
            ],
          ),
          _group(
            context,
            title: 'Downloads',
            children: [
              const _SettingTile(
                icon: Icons.folder_open_rounded,
                title: 'Download location',
                subtitle: 'Filexa app storage',
              ),
              SwitchListTile.adaptive(
                secondary: _tileIcon(context, Icons.wifi_rounded),
                title: const Text(
                  'Wi-Fi only',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Pause new downloads on mobile data'),
                value: _wifiOnly,
                onChanged: (value) => setState(() => _wifiOnly = value),
              ),
              SwitchListTile.adaptive(
                secondary: _tileIcon(context, Icons.notifications_none_rounded),
                title: const Text(
                  'Download notifications',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Progress and completion alerts'),
                value: _downloadNotifications,
                onChanged: (value) =>
                    setState(() => _downloadNotifications = value),
              ),
            ],
          ),
          _group(
            context,
            title: 'Browser & privacy',
            children: [
              SwitchListTile.adaptive(
                secondary: _tileIcon(context, Icons.content_paste_search_rounded),
                title: const Text(
                  'Clipboard link detection',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Show copied links on the browser home'),
                value: _clipboardDetection,
                onChanged: (value) =>
                    setState(() => _clipboardDetection = value),
              ),
              const _SettingTile(
                icon: Icons.shield_outlined,
                title: 'Clear browser data',
                subtitle: 'History, cookies and cached files',
              ),
            ],
          ),
          _group(
            context,
            title: 'Filexa services',
            children: const [
              _SettingTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Filexa Premium',
                subtitle: 'No ads and advanced tools • coming later',
              ),
              _SettingTile(
                icon: Icons.extension_outlined,
                title: 'Extensions',
                subtitle: 'Add only the tools you need • planned',
              ),
              _SettingTile(
                icon: Icons.cloud_outlined,
                title: 'Backup & cloud',
                subtitle: 'Keep important files available across devices',
              ),
              _SettingTile(
                icon: Icons.smart_toy_outlined,
                title: 'Filexa Assistant',
                subtitle: 'Smart file help • planned for a future release',
              ),
            ],
          ),
          _group(
            context,
            title: 'About',
            children: const [
              _SettingTile(
                icon: Icons.info_outline_rounded,
                title: 'About Filexa',
                subtitle: 'Version 1.1.0 • UI polish build',
              ),
              _SettingTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                subtitle: 'How Filexa protects and handles your data',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showThemePicker(ThemeMode current) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose theme',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              for (final mode in ThemeMode.values)
                ListTile(
                  leading: Icon(_themeIcon(mode)),
                  title: Text(_themeLabel(mode)),
                  trailing: Icon(
                    current == mode
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                  ),
                  onTap: () => Navigator.pop(context, mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;

    // The sheet has fully closed when the Future completes. Updating the root
    // theme here keeps route disposal and inherited-widget updates separate.
    AppController.setThemeMode(selected);
    if (mounted) setState(() {});
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Use device setting',
      };

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.system => Icons.brightness_auto_rounded,
      };

  static Widget _tileIcon(BuildContext context, IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: FilexaUi.softSurface(context),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }

  static Widget _group(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: FilexaUi.cardDecoration(context),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _SettingsPageState._tileIcon(context, icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
