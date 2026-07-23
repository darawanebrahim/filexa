import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/filexa_ui.dart';

class NewDownloadRequest {
  final String url;
  final String fileName;
  final String folder;

  const NewDownloadRequest({
    required this.url,
    required this.fileName,
    required this.folder,
  });
}

Future<NewDownloadRequest?> showNewDownloadDialog(BuildContext context) {
  return showModalBottomSheet<NewDownloadRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NewDownloadSheet(),
  );
}

class _NewDownloadSheet extends StatefulWidget {
  const _NewDownloadSheet();

  @override
  State<_NewDownloadSheet> createState() => _NewDownloadSheetState();
}

class _NewDownloadSheetState extends State<_NewDownloadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _fileNameController = TextEditingController();
  final _urlFocusNode = FocusNode();

  bool _isPasting = false;
  String _folder = 'Filexa app storage';

  @override
  void dispose() {
    _urlController.dispose();
    _fileNameController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  bool _isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String _suggestFileName(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (uri.pathSegments.isNotEmpty) {
      final lastSegment = Uri.decodeComponent(uri.pathSegments.last).trim();
      final hasUsefulExtension = RegExp(
        r'\.(pdf|zip|rar|7z|apk|iso|exe|msi|docx?|xlsx?|pptx?|mp3|m4a|wav|mp4|mkv|webm|avi|mov|jpg|jpeg|png|gif|webp)$',
        caseSensitive: false,
      ).hasMatch(lastSegment);
      if (lastSegment.isNotEmpty && hasUsefulExtension) {
        return lastSegment;
      }
    }

    final host = uri.host
        .replaceFirst('www.', '')
        .replaceFirst('m.', '')
        .split('.')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final prefix = host.isEmpty ? 'download' : host;
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _pasteFromClipboard() async {
    setState(() => _isPasting = true);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
    } else {
      _urlController.text = text;
      if (_fileNameController.text.trim().isEmpty) {
        _fileNameController.text = _suggestFileName(text);
      }
      _formKey.currentState?.validate();
    }

    if (mounted) setState(() => _isPasting = false);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final fileName = _fileNameController.text.trim().isEmpty
        ? _suggestFileName(_urlController.text)
        : _fileNameController.text.trim();

    Navigator.of(context).pop(
      NewDownloadRequest(
        url: _urlController.text.trim(),
        fileName: fileName,
        folder: _folder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, keyboardInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: FilexaUi.heroGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.download_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New download',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              )),
                          const SizedBox(height: 3),
                          Text(
                            'Add a direct HTTP or HTTPS file link.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionLabel(icon: Icons.link_rounded, label: 'File link'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _urlController,
                  focusNode: _urlFocusNode,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/file.pdf',
                    prefixIcon: const Icon(Icons.public_rounded),
                    suffixIcon: IconButton.filledTonal(
                      tooltip: 'Paste from clipboard',
                      onPressed: _isPasting ? null : _pasteFromClipboard,
                      icon: _isPasting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.content_paste_rounded),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Enter a file link.';
                    if (!_isValidUrl(text)) {
                      return 'Enter a valid HTTP or HTTPS link.';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (_fileNameController.text.trim().isEmpty &&
                        _isValidUrl(value)) {
                      _fileNameController.text = _suggestFileName(value);
                    }
                  },
                ),
                const SizedBox(height: 18),
                _SectionLabel(
                    icon: Icons.description_outlined, label: 'File name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fileNameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Automatic from link',
                    prefixIcon: Icon(Icons.insert_drive_file_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.contains(RegExp(r'[\\/:*?"<>|]'))) {
                      return 'File name contains unsupported characters.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),
                _SectionLabel(icon: Icons.folder_outlined, label: 'Save to'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _folder,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.folder_open_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Filexa app storage',
                      child: Text('Filexa app storage'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _folder = value);
                  },
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: FilexaUi.softSurface(context),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Filexa keeps unfinished downloads ready for pause and resume.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.download_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Start download',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
