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
            final office = allFiles.where((item) => isOfficeFile(item.name)).toList()
              ..sort((a, b) => b.modified.compareTo(a.modified));
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: FilexaPageHeader(
                    title: 'Native Office Studio',
                    subtitle: 'Open Word, Excel and PowerPoint inside Filexa — no Drive required.',
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
                      message: 'DOCX, XLSX and PPTX files will appear here. You can also create a new Word or Excel file.',
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
                          decoration: FilexaUi.cardDecoration(context, radius: 22, elevated: false),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: info.color.withValues(alpha: .14),
                              child: Icon(info.icon, color: info.color),
                            ),
                            title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('${info.label} • ${_formatBytes(item.size)}'),
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
      MaterialPageRoute<void>(builder: (_) => WordStudioPage(path: path, title: p.basename(path))),
    );
  }

  Future<void> _createExcel(BuildContext context, WidgetRef ref) async {
    final directory = await _outputDirectory();
    final path = _uniquePath(directory.path, 'Untitled spreadsheet', '.xlsx');
    await _service.writeXlsx(path, List.generate(8, (_) => List.filled(5, '')));
    if (!context.mounted) return;
    ref.invalidate(filesProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ExcelStudioPage(path: path, title: p.basename(path))),
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
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

bool isOfficeFile(String name) => const {'.docx', '.xlsx', '.pptx'}.contains(p.extension(name).toLowerCase());

({String label, IconData icon, Color color}) officeFileInfo(String name) {
  switch (p.extension(name).toLowerCase()) {
    case '.doc':
    case '.docx':
      return (label: 'Word', icon: Icons.description_rounded, color: const Color(0xFF2563EB));
    case '.xls':
    case '.xlsx':
      return (label: 'Excel', icon: Icons.grid_on_rounded, color: const Color(0xFF16A34A));
    case '.ppt':
    case '.pptx':
      return (label: 'PowerPoint', icon: Icons.slideshow_rounded, color: const Color(0xFFF97316));
    default:
      return (label: 'Office', icon: Icons.insert_drive_file_rounded, color: FilexaUi.primary);
  }
}

class WordStudioPage extends StatefulWidget {
  const WordStudioPage({super.key, required this.path, required this.title});
  final String path;
  final String title;

  @override
  State<WordStudioPage> createState() => _WordStudioPageState();
}

class _WordStudioPageState extends State<WordStudioPage> {
  final _service = const OfficeDocumentService();
  final _controller = TextEditingController();
  bool _loading = true;
  bool _dirty = false;
  double _fontSize = 16;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(_markDirty);
  }

  @override
  void dispose() {
    _controller.removeListener(_markDirty);
    _controller.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_loading && !_dirty) setState(() => _dirty = true);
  }

  Future<void> _load() async {
    try {
      final text = await _service.readDocxText(widget.path);
      if (!mounted) return;
      _controller.text = text;
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

  Future<void> _save() async {
    try {
      await _service.writeDocx(widget.path, _controller.text);
      if (!mounted) return;
      setState(() => _dirty = false);
      _snack('Saved ${p.basename(widget.path)}');
    } catch (error) {
      if (mounted) _snack('Could not save: $error');
    }
  }

  Future<void> _saveCopy() async {
    final target = _uniquePath(p.dirname(widget.path), '${p.basenameWithoutExtension(widget.path)} copy', '.docx');
    await _service.writeDocx(target, _controller.text);
    if (mounted) _snack('Saved copy: ${p.basename(target)}');
  }

  Future<void> _exportPdf() async {
    final target = _uniquePath(p.dirname(widget.path), p.basenameWithoutExtension(widget.path), '.pdf');
    await _service.exportTextPdf(target, _controller.text, title: p.basenameWithoutExtension(widget.path));
    if (mounted) _snack('PDF created: ${p.basename(target)}');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        appBar: AppBar(
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (_dirty) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.circle, size: 9, color: Colors.orange)),
            IconButton(tooltip: 'Save', onPressed: _loading ? null : _save, icon: const Icon(Icons.save_rounded)),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'copy') _saveCopy();
                if (value == 'pdf') _exportPdf();
                if (value == 'share') SharePlus.instance.share(ShareParams(files: [XFile(widget.path)]));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy_rounded), title: Text('Save a copy'))),
                PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_rounded), title: Text('Export PDF'))),
                PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share_rounded), title: Text('Share'))),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? FilexaEmptyState(icon: Icons.error_outline_rounded, title: 'Word file could not be opened', message: _error!)
                  : Column(
                      children: [
                        _WordRibbon(
                          fontSize: _fontSize,
                          onSmaller: () => setState(() => _fontSize = (_fontSize - 1).clamp(11, 28).toDouble()),
                          onLarger: () => setState(() => _fontSize = (_fontSize + 1).clamp(11, 28).toDouble()),
                          onSave: _save,
                          onExport: _exportPdf,
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            decoration: FilexaUi.cardDecoration(context, radius: 18, elevated: false),
                            child: TextField(
                              controller: _controller,
                              expands: true,
                              maxLines: null,
                              minLines: null,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              style: TextStyle(fontSize: _fontSize, height: 1.55),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(20),
                                hintText: 'Start writing…',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
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
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetContext, true), child: const Text('Discard'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await _save();
                        if (sheetContext.mounted) Navigator.pop(sheetContext, true);
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
      final cols = grid.fold<int>(6, (max, row) => row.length > max ? row.length : max);
      grid = grid.map((row) => [...row, ...List.filled(cols - row.length, '')]).toList();
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
    final target = _uniquePath(p.dirname(widget.path), p.basenameWithoutExtension(widget.path), '.pdf');
    await _service.exportGridPdf(target, _grid, title: p.basenameWithoutExtension(widget.path));
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

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_dirty) const Icon(Icons.circle, size: 9, color: Colors.orange),
          IconButton(tooltip: 'Save', onPressed: _loading ? null : _save, icon: const Icon(Icons.save_rounded)),
          IconButton(tooltip: 'Export PDF', onPressed: _loading ? null : _exportPdf, icon: const Icon(Icons.picture_as_pdf_rounded)),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? FilexaEmptyState(icon: Icons.error_outline_rounded, title: 'Spreadsheet could not be opened', message: _error!)
                : Column(
                    children: [
                      _ExcelRibbon(onAddRow: _addRow, onAddColumn: _addColumn, onSave: _save, onExport: _exportPdf),
                      Expanded(
                        child: Scrollbar(
                          controller: _vertical,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _vertical,
                            child: Scrollbar(
                              controller: _horizontal,
                              thumbVisibility: true,
                              notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
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
  const PowerPointStudioPage({super.key, required this.path, required this.title});
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
    final target = _uniquePath(p.dirname(widget.path), p.basenameWithoutExtension(widget.path), '.pdf');
    await _service.exportTextPdf(
      target,
      slides.asMap().entries.map((entry) => 'Slide ${entry.key + 1}\n${entry.value}').join('\n\n────────────\n\n'),
      title: p.basenameWithoutExtension(widget.path),
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF created: ${p.basename(target)}')));
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [IconButton(tooltip: 'Export PDF', onPressed: slides == null ? null : _exportPdf, icon: const Icon(Icons.picture_as_pdf_rounded))],
      ),
      body: SafeArea(
        child: _error != null
            ? FilexaEmptyState(icon: Icons.error_outline_rounded, title: 'Presentation could not be opened', message: _error!)
            : slides == null
                ? const Center(child: CircularProgressIndicator())
                : slides.isEmpty
                    ? const FilexaEmptyState(icon: Icons.slideshow_outlined, title: 'No slides found', message: 'This presentation does not contain readable slide text.')
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                            child: Row(
                              children: [
                                Text('Slide ${_index + 1} of ${slides.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                const Spacer(),
                                IconButton(onPressed: _index == 0 ? null : () => setState(() => _index--), icon: const Icon(Icons.chevron_left_rounded)),
                                IconButton(onPressed: _index >= slides.length - 1 ? null : () => setState(() => _index++), icon: const Icon(Icons.chevron_right_rounded)),
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
                                decoration: FilexaUi.cardDecoration(context, radius: 28),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    slides[_index].isEmpty ? 'Slide ${_index + 1}' : slides[_index],
                                    style: const TextStyle(fontSize: 18, height: 1.55, fontWeight: FontWeight.w600),
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
  const _OfficeCreateCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
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
                CircleAvatar(backgroundColor: color.withValues(alpha: .14), child: Icon(icon, color: color)),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordRibbon extends StatelessWidget {
  const _WordRibbon({required this.fontSize, required this.onSmaller, required this.onLarger, required this.onSave, required this.onExport});
  final double fontSize;
  final VoidCallback onSmaller;
  final VoidCallback onLarger;
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
          _RibbonButton(icon: Icons.picture_as_pdf_rounded, label: 'PDF', onTap: onExport),
          _RibbonButton(icon: Icons.text_decrease_rounded, label: 'A−', onTap: onSmaller),
          _RibbonButton(icon: Icons.text_increase_rounded, label: 'A+', onTap: onLarger),
          _RibbonChip(label: '${fontSize.round()} pt'),
        ],
      ),
    );
  }
}

class _ExcelRibbon extends StatelessWidget {
  const _ExcelRibbon({required this.onAddRow, required this.onAddColumn, required this.onSave, required this.onExport});
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
          _RibbonButton(icon: Icons.view_column_rounded, label: 'Column', onTap: onAddColumn),
          _RibbonButton(icon: Icons.picture_as_pdf_rounded, label: 'PDF', onTap: onExport),
        ],
      ),
    );
  }
}

class _RibbonButton extends StatelessWidget {
  const _RibbonButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label)),
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
                  decoration: BoxDecoration(color: FilexaUi.softSurface(context), border: Border.all(color: FilexaUi.border(context))),
                  child: Text(_columnName(col), style: const TextStyle(fontWeight: FontWeight.w900)),
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
                  decoration: BoxDecoration(color: FilexaUi.softSurface(context), border: Border.all(color: FilexaUi.border(context))),
                  child: Text('${row + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: FilexaUi.border(context))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: FilexaUi.border(context))),
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
