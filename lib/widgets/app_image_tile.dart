import 'package:flutter/material.dart';

import '../models/app_image.dart';

class AppImageTile extends StatelessWidget {
  const AppImageTile({
    super.key,
    required this.appImage,
    required this.onLaunch,
    required this.onRemove,
  });

  final AppImage appImage;
  final VoidCallback onLaunch;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: const Icon(Icons.apps),
        ),
        title: Text(appImage.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '添加于 ${_formatDate(appImage.addedAt)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              color: colorScheme.primary,
              tooltip: '启动',
              onPressed: onLaunch,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: colorScheme.error,
              tooltip: '删除',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
