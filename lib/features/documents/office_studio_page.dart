import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_item.dart';
import '../../core/providers/file_provider.dart';
import '../../core/services/office_document_service.dart';
import '../../theme/filexa_ui.dart';

class OfficeStudioPage extends ConsumerWidget {
  const OfficeStudioPage({super.key});

  static const _service = OfficeDocumentService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(filesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Studio'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(filesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: files.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => FilexaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Office files could not be loaded',
            message: '$error',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(filesProvider),
          ),
          data: (allFiles) {
            final office =
                allFiles.where((item) => isOfficeFile(item.name)).toList()
                  ..sort((a, b) => b.modified.compareTo(a.modified));
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: FilexaPageHeader(
                    title: 'Native Office Studio',
                    subtitle:
                        'Open Word, Excel and PowerPoint inside Filexa — no Drive required.',
                    icon: Icons.business_center_rounded,
                  ),
                ),
                SliverToBoxAdapter(child: _createStrip(context, ref)),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: FilexaSectionTitle(title: 'Office files'),
                  ),
                ),
                if (office.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: FilexaEmptyState(
                      icon: Icons.description_outlined,
                      title: 'No Office files yet',
                      message:
                          'DOCX, XLSX and PPTX files will appear here. You can also create a new Word or Excel file.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                    sliver: SliverList.separated(
                      itemCount: office.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = office[index];
                        final info = officeFileInfo(item.name);
                        return Container(
                          decoration: FilexaUi.cardDecoration(
                            context,
                            radius: 22,
                            elevated: false,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: info.color.withValues(
                                alpha: .14,
                              ),
                              child: Icon(info.icon, color: info.color),
                            ),
                            title: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${info.label} • ${_formatBytes(item.size)}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => openOfficeFile(context, item),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _createStrip(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _OfficeCreateCard(
              icon: Icons.description_rounded,
              color: const Color(0xFF2563EB),
              title: 'New Word',
              subtitle: 'Create a DOCX document',
              onTap: () => _createWord(context, ref),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _OfficeCreateCard(
              icon: Icons.grid_on_rounded,
              color: const Color(0xFF16A34A),
              title: 'New Excel',
              subtitle: 'Create an XLSX sheet',
              onTap: () => _createExcel(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createWord(BuildContext context, WidgetRef ref) async {
    final directory = await _outputDirectory();
    final path = _uniquePath(directory.path, 'Untitled document', '.docx');
    await _service.writeDocx(path, '');
    if (!context.mounted) return;
    ref.invalidate(filesProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WordStudioPage(path: path, title: p.basename(path)),
      ),
    );
  }

  Future<void> _createExcel(BuildContext context, WidgetRef ref) async {
    final directory = await _outputDirectory();
    final path = _uniquePath(directory.path, 'Untitled spreadsheet', '.xlsx');
    await _service.writeXlsx(path, List.generate(8, (_) => List.filled(5, '')));
    if (!context.mounted) return;
    ref.invalidate(filesProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExcelStudioPage(path: path, title: p.basename(path)),
      ),
    );
  }
}

Future<void> openOfficeFile(BuildContext context, FileItem item) async {
  final ext = p.extension(item.name).toLowerCase();
  Widget page;
  if (ext == '.docx' || ext == '.doc') {
    page = WordStudioPage(path: item.path, title: item.name);
  } else if (ext == '.xlsx' || ext == '.xls') {
    page = ExcelStudioPage(path: item.path, title: item.name);
  } else if (ext == '.pptx' || ext == '.ppt') {
    page = PowerPointStudioPage(path: item.path, title: item.name);
  } else {
    return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => page));
}

bool isOfficeFile(String name) =>
    const {'.docx', '.xlsx', '.pptx'}.contains(p.extension(name).toLowerCase());

({String label, IconData icon, Color color}) officeFileInfo(String name) {
  switch (p.extension(name).toLowerCase()) {
    case '.doc':
    case '.docx':
      return (
        label: 'Word',
        icon: Icons.description_rounded,
        color: const Color(0xFF2563EB),
      );
    case '.xls':
    case '.xlsx':
      return (
        label: 'Excel',
        icon: Icons.grid_on_rounded,
        color: const Color(0xFF16A34A),
      );
    case '.ppt':
    case '.pptx':
      return (
        label: 'PowerPoint',
        icon: Icons.slideshow_rounded,
        color: const Color(0xFFF97316),
      );
    default:
      return (
        label: 'Office',
        icon: Icons.insert_drive_file_rounded,
        color: FilexaUi.primary,
      );
  }
}

class WordStudioPage extends StatefulWidget {
  const WordStudioPage({super.key, required this.path, required this.title});
  final String path;
  final String title;

  @override
  State<WordStudioPage> createState() => _WordStudioPageState();
}

enum _WordTab { home, insert, review, export }

class _WordStudioPageState extends State<WordStudioPage> {
  final _service = const OfficeDocumentService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<TextEditingValue> _undoStack = <TextEditingValue>[];
  final List<TextEditingValue> _redoStack = <TextEditingValue>[];

  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  bool _focusMode = false;
  bool _bold = false;
  bool _italic = false;
  bool _underline = false;
  double _fontSize = 16;
  double _lineHeight = 1.55;
  TextAlign _textAlign = TextAlign.start;
  String _fontFamily = 'System';
  String? _error;
  _WordTab _tab = _WordTab.home;
  Timer? _autoSaveTimer;
  Timer? _historyTimer;
  TextEditingValue _lastHistoryValue = const TextEditingValue();

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _historyTimer?.cancel();
    _controller.removeListener(_onDocumentChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    if (_loading) return;
    if (!_dirty) setState(() => _dirty = true);
    _scheduleAutoSave();
    _scheduleHistorySnapshot();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _dirty && !_saving) _save(silent: true);
    });
  }

  void _scheduleHistorySnapshot() {
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(milliseconds: 650), () {
      final value = _controller.value;
      if (value.text == _lastHistoryValue.text) return;
      _undoStack.add(_lastHistoryValue);
      if (_undoStack.length > 80) _undoStack.removeAt(0);
      _redoStack.clear();
      _lastHistoryValue = value;
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    try {
      final text = await _service.readDocxText(widget.path);
      if (!mounted) return;
      _controller.text = text;
      _lastHistoryValue = _controller.value;
      setState(() {
        _loading = false;
        _dirty = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _save({bool silent = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.writeDocx(widget.path, _controller.text);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      if (!silent) _snack('Saved ${p.basename(widget.path)}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (!silent) _snack('Could not save: $error');
    }
  }

  Future<void> _saveCopy() async {
    final target = _uniquePath(
      p.dirname(widget.path),
      '${p.basenameWithoutExtension(widget.path)} copy',
      '.docx',
    );
    await _service.writeDocx(target, _controller.text);
    if (mounted) _snack('Saved copy: ${p.basename(target)}');
  }

  Future<void> _exportPdf() async {
    final target = _uniquePath(
      p.dirname(widget.path),
      p.basenameWithoutExtension(widget.path),
      '.pdf',
    );
    await _service.exportTextPdf(
      target,
      _controller.text,
      title: p.basenameWithoutExtension(widget.path),
    );
    if (mounted) _snack('PDF created: ${p.basename(target)}');
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _historyTimer?.cancel();
    final current = _controller.value;
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    _controller.value = previous;
    _lastHistoryValue = previous;
    setState(() => _dirty = true);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _historyTimer?.cancel();
    final current = _controller.value;
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    _controller.value = next;
    _lastHistoryValue = next;
    setState(() => _dirty = true);
  }

  void _insertText(String text) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : _controller.text.length;
    final updated = _controller.text.replaceRange(start, end, text);
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _focusNode.requestFocus();
  }

  void _toggleLinePrefix(String prefix) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : 0;
    final end = selection.isValid ? selection.end : _controller.text.length;
    final before = _controller.text.substring(0, start);
    final selected = _controller.text.substring(start, end);
    final after = _controller.text.substring(end);
    final lines = selected.split('\n');
    final allPrefixed = lines
        .where((line) => line.trim().isNotEmpty)
        .every((line) => line.startsWith(prefix));
    final changed = lines
        .map((line) {
          if (line.trim().isEmpty) return line;
          return allPrefixed && line.startsWith(prefix)
              ? line.substring(prefix.length)
              : '$prefix$line';
        })
        .join('\n');
    _controller.value = TextEditingValue(
      text: '$before$changed$after',
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + changed.length,
      ),
    );
    _focusNode.requestFocus();
  }

  void _numberSelection() {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : 0;
    final end = selection.isValid ? selection.end : _controller.text.length;
    final before = _controller.text.substring(0, start);
    final selected = _controller.text.substring(start, end);
    final after = _controller.text.substring(end);
    var number = 1;
    final changed = selected
        .split('\n')
        .map((line) {
          if (line.trim().isEmpty) return line;
          return '${number++}. ${line.replaceFirst(RegExp(r'^\d+\.\s+'), '')}';
        })
        .join('\n');
    _controller.value = TextEditingValue(
      text: '$before$changed$after',
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + changed.length,
      ),
    );
    _focusNode.requestFocus();
  }

  void _changeSelectionCase(bool upper) {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _snack('Select text first');
      return;
    }
    final selected = selection.textInside(_controller.text);
    final changed = upper ? selected.toUpperCase() : selected.toLowerCase();
    final updated =
        selection.textBefore(_controller.text) +
        changed +
        selection.textAfter(_controller.text);
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + changed.length,
      ),
    );
    _focusNode.requestFocus();
  }

  void _duplicateSelection() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _snack('Select text first');
      return;
    }
    final selected = selection.textInside(_controller.text);
    _insertText('$selected$selected');
  }

  Future<void> _showSearchReplace() async {
    final result = await showModalBottomSheet<_SearchReplaceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _WordSearchReplaceSheet(text: _controller.text),
    );
    if (!mounted || result == null) return;

    if (result.replaceAll && result.query.isNotEmpty) {
      final replaced = _controller.text.replaceAll(
        result.query,
        result.replacement,
      );
      _controller.value = TextEditingValue(
        text: replaced,
        selection: TextSelection.collapsed(offset: replaced.length),
      );
      _snack('Replaced all matches');
      return;
    }

    if (result.query.isEmpty) return;
    final startFrom = _controller.selection.isValid
        ? _controller.selection.end
        : 0;
    var index = _controller.text.indexOf(result.query, startFrom);
    if (index < 0) index = _controller.text.indexOf(result.query);
    if (index >= 0) {
      _controller.selection = TextSelection(
        baseOffset: index,
        extentOffset: index + result.query.length,
      );
      _focusNode.requestFocus();
    } else {
      _snack('No matches found');
    }
  }

  Future<void> _showDocumentInfo() async {
    final text = _controller.text;
    final words = _wordCount(text);
    final chars = text.runes.length;
    final lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: 'Document insights',
        subtitle: 'Live writing statistics',
        icon: Icons.analytics_outlined,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(label: 'Words', value: '$words'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(label: 'Characters', value: '$chars'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(label: 'Lines', value: '$lines'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  TextStyle _editorTextStyle(BuildContext context) {
    String? family;
    if (_fontFamily == 'Serif') family = 'serif';
    if (_fontFamily == 'Mono') family = 'monospace';
    return TextStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      fontFamily: family,
      fontWeight: _bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
      decoration: _underline ? TextDecoration.underline : TextDecoration.none,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111827)
          : const Color(0xFF111827),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final leave = await _confirmDiscard();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF090D17)
            : const Color(0xFFF3F4F8),
        appBar: _focusMode
            ? null
            : AppBar(
                titleSpacing: 4,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basenameWithoutExtension(widget.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      _saving
                          ? 'Saving…'
                          : _dirty
                          ? 'Unsaved changes'
                          : 'Saved automatically',
                      style: TextStyle(
                        fontSize: 11,
                        color: _dirty ? FilexaUi.warning : FilexaUi.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Undo',
                    onPressed: _undoStack.isEmpty ? null : _undo,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    onPressed: _redoStack.isEmpty ? null : _redo,
                    icon: const Icon(Icons.redo_rounded),
                  ),
                  IconButton(
                    tooltip: 'Save',
                    onPressed: _loading ? null : () => _save(),
                    icon: const Icon(Icons.save_rounded),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'focus') setState(() => _focusMode = true);
                      if (value == 'copy') _saveCopy();
                      if (value == 'share')
                        SharePlus.instance.share(
                          ShareParams(files: [XFile(widget.path)]),
                        );
                      if (value == 'info') _showDocumentInfo();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'focus',
                        child: ListTile(
                          leading: Icon(Icons.fullscreen_rounded),
                          title: Text('Focus mode'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: ListTile(
                          leading: Icon(Icons.copy_rounded),
                          title: Text('Save a copy'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.share_rounded),
                          title: Text('Share document'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'info',
                        child: ListTile(
                          leading: Icon(Icons.analytics_outlined),
                          title: Text('Document insights'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? FilexaEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Word file could not be opened',
                  message: _error!,
                )
              : Column(
                  children: [
                    if (!_focusMode) ...[
                      _WordTabBar(
                        selected: _tab,
                        onChanged: (tab) => setState(() => _tab = tab),
                      ),
                      _WordCommandBar(
                        tab: _tab,
                        fontSize: _fontSize,
                        fontFamily: _fontFamily,
                        bold: _bold,
                        italic: _italic,
                        underline: _underline,
                        textAlign: _textAlign,
                        canUndo: _undoStack.isNotEmpty,
                        canRedo: _redoStack.isNotEmpty,
                        onBold: () => setState(() => _bold = !_bold),
                        onItalic: () => setState(() => _italic = !_italic),
                        onUnderline: () =>
                            setState(() => _underline = !_underline),
                        onFontSmaller: () => setState(
                          () => _fontSize = (_fontSize - 1)
                              .clamp(10, 44)
                              .toDouble(),
                        ),
                        onFontLarger: () => setState(
                          () => _fontSize = (_fontSize + 1)
                              .clamp(10, 44)
                              .toDouble(),
                        ),
                        onFontFamily: () => _showFontPicker(),
                        onAlign: (align) => setState(() => _textAlign = align),
                        onUndo: _undo,
                        onRedo: _redo,
                        onSearch: _showSearchReplace,
                        onInsertDate: () => _insertText(_todayLabel()),
                        onInsertDivider: () =>
                            _insertText('\n────────────────────────\n'),
                        onBulletList: () => _toggleLinePrefix('• '),
                        onNumberList: _numberSelection,
                        onChecklist: () => _toggleLinePrefix('☐ '),
                        onUppercase: () => _changeSelectionCase(true),
                        onLowercase: () => _changeSelectionCase(false),
                        onDuplicate: _duplicateSelection,
                        onSave: () => _save(),
                        onSaveCopy: _saveCopy,
                        onExportPdf: _exportPdf,
                        onShare: () => SharePlus.instance.share(
                          ShareParams(files: [XFile(widget.path)]),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                _focusMode ? 12 : 16,
                                _focusMode ? 10 : 18,
                                _focusMode ? 12 : 16,
                                96,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 820,
                                  ),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 920,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFEFC),
                                      borderRadius: BorderRadius.circular(
                                        _focusMode ? 8 : 14,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: .10,
                                          ),
                                          blurRadius: 28,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      maxLines: null,
                                      minLines: 32,
                                      keyboardType: TextInputType.multiline,
                                      textAlign: _textAlign,
                                      textAlignVertical: TextAlignVertical.top,
                                      style: _editorTextStyle(context),
                                      cursorColor: FilexaUi.primary,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.fromLTRB(
                                          54,
                                          56,
                                          54,
                                          72,
                                        ),
                                        hintText:
                                            'Start writing your document…',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_focusMode)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Material(
                                color: Colors.black.withValues(alpha: .55),
                                borderRadius: BorderRadius.circular(16),
                                child: IconButton(
                                  tooltip: 'Exit focus mode',
                                  color: Colors.white,
                                  onPressed: () =>
                                      setState(() => _focusMode = false),
                                  icon: const Icon(
                                    Icons.fullscreen_exit_rounded,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!_focusMode)
                      _WordStatusBar(
                        text: _controller.text,
                        fontSize: _fontSize,
                        lineHeight: _lineHeight,
                        onLineHeight: () => setState(() {
                          _lineHeight = _lineHeight >= 1.9
                              ? 1.25
                              : _lineHeight + .15;
                        }),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _showFontPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FilexaPremiumSheet(
        title: 'Font family',
        subtitle: 'Choose your writing style',
        icon: Icons.font_download_outlined,
        child: Column(
          children: [
            for (final family in const ['System', 'Serif', 'Mono'])
              ListTile(
                leading: Icon(
                  _fontFamily == family
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                ),
                title: Text(
                  family,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  family == 'System'
                      ? 'Modern and clean'
                      : family == 'Serif'
                      ? 'Classic document style'
                      : 'Code and fixed-width text',
                ),
                onTap: () => Navigator.pop(sheetContext, family),
              ),
          ],
        ),
      ),
    );
    if (choice != null && mounted) setState(() => _fontFamily = choice);
  }

  Future<bool> _confirmDiscard() async {
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => FilexaPremiumSheet(
            title: 'Unsaved changes',
            subtitle: 'Save before leaving this document?',
            icon: Icons.edit_note_rounded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await _save();
                        if (sheetContext.mounted)
                          Navigator.pop(sheetContext, true);
                      },
                      child: const Text('Save & leave'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }
}

class _WordTabBar extends StatelessWidget {
  const _WordTabBar({required this.selected, required this.onChanged});
  final _WordTab selected;
  final ValueChanged<_WordTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FilexaUi.surface(context),
      child: SizedBox(
        height: 46,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          scrollDirection: Axis.horizontal,
          children: [
            _tab(context, _WordTab.home, 'Home', Icons.home_outlined),
            _tab(
              context,
              _WordTab.insert,
              'Insert',
              Icons.add_circle_outline_rounded,
            ),
            _tab(context, _WordTab.review, 'Review', Icons.fact_check_outlined),
            _tab(context, _WordTab.export, 'Export', Icons.ios_share_rounded),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, _WordTab tab, String label, IconData icon) {
    final active = selected == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            gradient: active ? FilexaUi.accentGradient : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: active
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCommandBar extends StatelessWidget {
  const _WordCommandBar({
    required this.tab,
    required this.fontSize,
    required this.fontFamily,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.textAlign,
    required this.canUndo,
    required this.canRedo,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onFontSmaller,
    required this.onFontLarger,
    required this.onFontFamily,
    required this.onAlign,
    required this.onUndo,
    required this.onRedo,
    required this.onSearch,
    required this.onInsertDate,
    required this.onInsertDivider,
    required this.onBulletList,
    required this.onNumberList,
    required this.onChecklist,
    required this.onUppercase,
    required this.onLowercase,
    required this.onDuplicate,
    required this.onSave,
    required this.onSaveCopy,
    required this.onExportPdf,
    required this.onShare,
  });

  final _WordTab tab;
  final double fontSize;
  final String fontFamily;
  final bool bold;
  final bool italic;
  final bool underline;
  final TextAlign textAlign;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onFontSmaller;
  final VoidCallback onFontLarger;
  final VoidCallback onFontFamily;
  final ValueChanged<TextAlign> onAlign;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSearch;
  final VoidCallback onInsertDate;
  final VoidCallback onInsertDivider;
  final VoidCallback onBulletList;
  final VoidCallback onNumberList;
  final VoidCallback onChecklist;
  final VoidCallback onUppercase;
  final VoidCallback onLowercase;
  final VoidCallback onDuplicate;
  final VoidCallback onSave;
  final VoidCallback onSaveCopy;
  final VoidCallback onExportPdf;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final actions = switch (tab) {
      _WordTab.home => <Widget>[
        _WordTool(
          icon: Icons.undo_rounded,
          label: 'Undo',
          enabled: canUndo,
          onTap: onUndo,
        ),
        _WordTool(
          icon: Icons.redo_rounded,
          label: 'Redo',
          enabled: canRedo,
          onTap: onRedo,
        ),
        _WordTool(
          icon: Icons.format_bold_rounded,
          label: 'Bold',
          selected: bold,
          onTap: onBold,
        ),
        _WordTool(
          icon: Icons.format_italic_rounded,
          label: 'Italic',
          selected: italic,
          onTap: onItalic,
        ),
        _WordTool(
          icon: Icons.format_underlined_rounded,
          label: 'Underline',
          selected: underline,
          onTap: onUnderline,
        ),
        _WordTool(
          icon: Icons.format_list_bulleted_rounded,
          label: 'Bullets',
          onTap: onBulletList,
        ),
        _WordTool(
          icon: Icons.format_list_numbered_rounded,
          label: 'Number',
          onTap: onNumberList,
        ),
        _WordTool(
          icon: Icons.font_download_outlined,
          label: fontFamily,
          onTap: onFontFamily,
        ),
        _WordTool(
          icon: Icons.text_decrease_rounded,
          label: 'A−',
          onTap: onFontSmaller,
        ),
        _WordTool(
          icon: Icons.text_increase_rounded,
          label: '${fontSize.round()}',
          onTap: onFontLarger,
        ),
        _WordTool(
          icon: Icons.format_align_left_rounded,
          label: 'Left',
          selected: textAlign == TextAlign.left || textAlign == TextAlign.start,
          onTap: () => onAlign(TextAlign.left),
        ),
        _WordTool(
          icon: Icons.format_align_center_rounded,
          label: 'Center',
          selected: textAlign == TextAlign.center,
          onTap: () => onAlign(TextAlign.center),
        ),
        _WordTool(
          icon: Icons.format_align_right_rounded,
          label: 'Right',
          selected: textAlign == TextAlign.right || textAlign == TextAlign.end,
          onTap: () => onAlign(TextAlign.right),
        ),
      ],
      _WordTab.insert => <Widget>[
        _WordTool(
          icon: Icons.calendar_today_outlined,
          label: 'Date',
          onTap: onInsertDate,
        ),
        _WordTool(
          icon: Icons.horizontal_rule_rounded,
          label: 'Divider',
          onTap: onInsertDivider,
        ),
        _WordTool(
          icon: Icons.check_box_outlined,
          label: 'Checklist',
          onTap: onChecklist,
        ),
        _WordTool(
          icon: Icons.control_point_duplicate_rounded,
          label: 'Duplicate',
          onTap: onDuplicate,
        ),
        _WordTool(
          icon: Icons.image_outlined,
          label: 'Image',
          enabled: false,
          onTap: () {},
        ),
        _WordTool(
          icon: Icons.table_chart_outlined,
          label: 'Table',
          enabled: false,
          onTap: () {},
        ),
      ],
      _WordTab.review => <Widget>[
        _WordTool(
          icon: Icons.manage_search_rounded,
          label: 'Find / Replace',
          onTap: onSearch,
        ),
        _WordTool(
          icon: Icons.text_fields_rounded,
          label: 'UPPER',
          onTap: onUppercase,
        ),
        _WordTool(
          icon: Icons.text_fields_rounded,
          label: 'lower',
          onTap: onLowercase,
        ),
        _WordTool(
          icon: Icons.spellcheck_rounded,
          label: 'Spelling',
          enabled: false,
          onTap: () {},
        ),
        _WordTool(
          icon: Icons.translate_rounded,
          label: 'Translate',
          enabled: false,
          onTap: () {},
        ),
      ],
      _WordTab.export => <Widget>[
        _WordTool(icon: Icons.save_rounded, label: 'Save', onTap: onSave),
        _WordTool(
          icon: Icons.copy_rounded,
          label: 'Save copy',
          onTap: onSaveCopy,
        ),
        _WordTool(
          icon: Icons.picture_as_pdf_rounded,
          label: 'PDF',
          onTap: onExportPdf,
        ),
        _WordTool(icon: Icons.share_rounded, label: 'Share', onTap: onShare),
      ],
    };

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: FilexaUi.surface(context),
        border: Border(bottom: BorderSide(color: FilexaUi.border(context))),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        scrollDirection: Axis.horizontal,
        children: actions,
      ),
    );
  }
}

class _WordTool extends StatelessWidget {
  const _WordTool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 68,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? FilexaUi.primary.withValues(alpha: .14)
                : FilexaUi.softSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? FilexaUi.primary.withValues(alpha: .55)
                  : FilexaUi.border(context),
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : .38,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? FilexaUi.primary : onSurface,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? FilexaUi.primary : null,
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

class _WordStatusBar extends StatelessWidget {
  const _WordStatusBar({
    required this.text,
    required this.fontSize,
    required this.lineHeight,
    required this.onLineHeight,
  });
  final String text;
  final double fontSize;
  final double lineHeight;
  final VoidCallback onLineHeight;

  @override
  Widget build(BuildContext context) {
    final words = _wordCount(text);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FilexaUi.surface(context),
        border: Border(top: BorderSide(color: FilexaUi.border(context))),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: FilexaUi.success,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '$words words',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 14),
          Text(
            '${text.runes.length} chars',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          InkWell(
            onTap: onLineHeight,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: Text(
                'Line ${lineHeight.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${fontSize.round()} pt',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SearchReplaceResult {
  const _SearchReplaceResult({
    required this.query,
    required this.replacement,
    required this.replaceAll,
  });
  final String query;
  final String replacement;
  final bool replaceAll;
}

class _WordSearchReplaceSheet extends StatefulWidget {
  const _WordSearchReplaceSheet({required this.text});
  final String text;

  @override
  State<_WordSearchReplaceSheet> createState() =>
      _WordSearchReplaceSheetState();
}

class _WordSearchReplaceSheetState extends State<_WordSearchReplaceSheet> {
  final _query = TextEditingController();
  final _replacement = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    _replacement.dispose();
    super.dispose();
  }

  int get _matches {
    final q = _query.text;
    if (q.isEmpty) return 0;
    var count = 0;
    var offset = 0;
    while (true) {
      final index = widget.text.indexOf(q, offset);
      if (index < 0) break;
      count++;
      offset = index + q.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return FilexaPremiumSheet(
      title: 'Find & replace',
      subtitle: _query.text.isEmpty
          ? 'Search inside this document'
          : '$_matches matches found',
      icon: Icons.manage_search_rounded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Find',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _replacement,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.find_replace_rounded),
                labelText: 'Replace with',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _query.text.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            _SearchReplaceResult(
                              query: _query.text,
                              replacement: _replacement.text,
                              replaceAll: false,
                            ),
                          ),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Find next'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _query.text.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            _SearchReplaceResult(
                              query: _query.text,
                              replacement: _replacement.text,
                              replaceAll: true,
                            ),
                          ),
                    icon: const Icon(Icons.find_replace_rounded),
                    label: const Text('Replace all'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: FilexaUi.softSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FilexaUi.border(context)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

int _wordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return RegExp(r'\S+').allMatches(trimmed).length;
}

String _todayLabel() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

class ExcelStudioPage extends StatefulWidget {
  const ExcelStudioPage({super.key, required this.path, required this.title});
  final String path;
  final String title;

  @override
  State<ExcelStudioPage> createState() => _ExcelStudioPageState();
}

class _ExcelStudioPageState extends State<ExcelStudioPage> {
  final _service = const OfficeDocumentService();
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  List<List<String>> _grid = [];
  bool _loading = true;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var grid = await _service.readXlsxGrid(widget.path);
      if (grid.isEmpty) grid = List.generate(12, (_) => List.filled(6, ''));
      final cols = grid.fold<int>(
        6,
        (max, row) => row.length > max ? row.length : max,
      );
      grid = grid
          .map((row) => [...row, ...List.filled(cols - row.length, '')])
          .toList();
      if (!mounted) return;
      setState(() {
        _grid = grid;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _save() async {
    await _service.writeXlsx(widget.path, _grid);
    if (!mounted) return;
    setState(() => _dirty = false);
    _snack('Spreadsheet saved');
  }

  Future<void> _exportPdf() async {
    final target = _uniquePath(
      p.dirname(widget.path),
      p.basenameWithoutExtension(widget.path),
      '.pdf',
    );
    await _service.exportGridPdf(
      target,
      _grid,
      title: p.basenameWithoutExtension(widget.path),
    );
    if (mounted) _snack('PDF created: ${p.basename(target)}');
  }

  void _addRow() => setState(() {
    final columns = _grid.isEmpty ? 6 : _grid.first.length;
    _grid.add(List.filled(columns, ''));
    _dirty = true;
  });

  void _addColumn() => setState(() {
    if (_grid.isEmpty) _grid = List.generate(12, (_) => <String>[]);
    for (final row in _grid) row.add('');
    _dirty = true;
  });

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_dirty) const Icon(Icons.circle, size: 9, color: Colors.orange),
          IconButton(
            tooltip: 'Save',
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save_rounded),
          ),
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _loading ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? FilexaEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Spreadsheet could not be opened',
                message: _error!,
              )
            : Column(
                children: [
                  _ExcelRibbon(
                    onAddRow: _addRow,
                    onAddColumn: _addColumn,
                    onSave: _save,
                    onExport: _exportPdf,
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _vertical,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _vertical,
                        child: Scrollbar(
                          controller: _horizontal,
                          thumbVisibility: true,
                          notificationPredicate: (notification) =>
                              notification.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _horizontal,
                            scrollDirection: Axis.horizontal,
                            child: _SpreadsheetGrid(
                              grid: _grid,
                              onChanged: (row, col, value) {
                                _grid[row][col] = value;
                                if (!_dirty) setState(() => _dirty = true);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class PowerPointStudioPage extends StatefulWidget {
  const PowerPointStudioPage({
    super.key,
    required this.path,
    required this.title,
  });
  final String path;
  final String title;

  @override
  State<PowerPointStudioPage> createState() => _PowerPointStudioPageState();
}

class _PowerPointStudioPageState extends State<PowerPointStudioPage> {
  final _service = const OfficeDocumentService();
  List<String>? _slides;
  String? _error;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final slides = await _service.readPptxSlides(widget.path);
      if (mounted) setState(() => _slides = slides);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _exportPdf() async {
    final slides = _slides ?? const <String>[];
    final target = _uniquePath(
      p.dirname(widget.path),
      p.basenameWithoutExtension(widget.path),
      '.pdf',
    );
    await _service.exportTextPdf(
      target,
      slides
          .asMap()
          .entries
          .map((entry) => 'Slide ${entry.key + 1}\n${entry.value}')
          .join('\n\n────────────\n\n'),
      title: p.basenameWithoutExtension(widget.path),
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF created: ${p.basename(target)}')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            onPressed: slides == null ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? FilexaEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Presentation could not be opened',
                message: _error!,
              )
            : slides == null
            ? const Center(child: CircularProgressIndicator())
            : slides.isEmpty
            ? const FilexaEmptyState(
                icon: Icons.slideshow_outlined,
                title: 'No slides found',
                message:
                    'This presentation does not contain readable slide text.',
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'Slide ${_index + 1} of ${slides.length}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _index == 0
                              ? null
                              : () => setState(() => _index--),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        IconButton(
                          onPressed: _index >= slides.length - 1
                              ? null
                              : () => setState(() => _index++),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        key: ValueKey(_index),
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        padding: const EdgeInsets.all(28),
                        decoration: FilexaUi.cardDecoration(
                          context,
                          radius: 28,
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            slides[_index].isEmpty
                                ? 'Slide ${_index + 1}'
                                : slides[_index],
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.55,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OfficeCreateCard extends StatelessWidget {
  const _OfficeCreateCard({
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FilexaUi.cardDecoration(context, radius: 22, elevated: false),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .14),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExcelRibbon extends StatelessWidget {
  const _ExcelRibbon({
    required this.onAddRow,
    required this.onAddColumn,
    required this.onSave,
    required this.onExport,
  });
  final VoidCallback onAddRow;
  final VoidCallback onAddColumn;
  final VoidCallback onSave;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          _RibbonButton(icon: Icons.save_rounded, label: 'Save', onTap: onSave),
          _RibbonButton(icon: Icons.add_rounded, label: 'Row', onTap: onAddRow),
          _RibbonButton(
            icon: Icons.view_column_rounded,
            label: 'Column',
            onTap: onAddColumn,
          ),
          _RibbonButton(
            icon: Icons.picture_as_pdf_rounded,
            label: 'PDF',
            onTap: onExport,
          ),
        ],
      ),
    );
  }
}

class _RibbonButton extends StatelessWidget {
  const _RibbonButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _RibbonChip extends StatelessWidget {
  const _RibbonChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Chip(label: Text(label)),
  );
}

class _SpreadsheetGrid extends StatelessWidget {
  const _SpreadsheetGrid({required this.grid, required this.onChanged});
  final List<List<String>> grid;
  final void Function(int row, int col, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final cols = grid.isEmpty ? 0 : grid.first.length;
    const cellWidth = 132.0;
    const cellHeight = 48.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 44, height: cellHeight),
              for (var col = 0; col < cols; col++)
                Container(
                  width: cellWidth,
                  height: cellHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FilexaUi.softSurface(context),
                    border: Border.all(color: FilexaUi.border(context)),
                  ),
                  child: Text(
                    _columnName(col),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          for (var row = 0; row < grid.length; row++)
            Row(
              children: [
                Container(
                  width: 44,
                  height: cellHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FilexaUi.softSurface(context),
                    border: Border.all(color: FilexaUi.border(context)),
                  ),
                  child: Text(
                    '${row + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                for (var col = 0; col < cols; col++)
                  SizedBox(
                    width: cellWidth,
                    height: cellHeight,
                    child: TextFormField(
                      key: ValueKey('$row:$col:${grid[row][col]}'),
                      initialValue: grid[row][col],
                      onChanged: (value) => onChanged(row, col, value),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: FilexaUi.border(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: FilexaUi.border(context),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<Directory> _outputDirectory() async {
  final downloads = await getDownloadsDirectory();
  if (downloads != null) return downloads;
  return getApplicationDocumentsDirectory();
}

String _uniquePath(String directory, String base, String extension) {
  var path = p.join(directory, '$base$extension');
  var index = 1;
  while (File(path).existsSync()) {
    path = p.join(directory, '$base ($index)$extension');
    index++;
  }
  return path;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

String _columnName(int index) {
  var number = index + 1;
  var result = '';
  while (number > 0) {
    final remainder = (number - 1) % 26;
    result = String.fromCharCode(65 + remainder) + result;
    number = (number - 1) ~/ 26;
  }
  return result;
}
