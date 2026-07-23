import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: const [
        _ActionItem(Icons.download, 'Download'),
        _ActionItem(Icons.folder, 'Files'),
        _ActionItem(Icons.language, 'Browser'),
        _ActionItem(Icons.picture_as_pdf, 'PDF'),
        _ActionItem(Icons.video_library, 'Media'),
        _ActionItem(Icons.lock, 'Vault'),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ActionItem(this.icon, this.title);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          SizedBox(height: 8),
          Text(title),
        ],
      ),
    );
  }
}