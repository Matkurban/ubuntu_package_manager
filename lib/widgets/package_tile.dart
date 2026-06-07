import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/package.dart';

class PackageTile extends StatelessWidget {
  const PackageTile({
    super.key,
    required this.package,
    required this.onUninstall,
    this.isUninstalling = false,
    this.highlightQuery = '',
  });

  final Package package;
  final VoidCallback onUninstall;
  final bool isUninstalling;

  /// 搜索关键词，非空时在标题中高亮显示
  final String highlightQuery;

  static const double _iconSize = 44;
  static const double _iconRadius = 8;

  Widget _fallback(ColorScheme colorScheme) {
    return Container(
      width: _iconSize,
      height: _iconSize,
      color: colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        package.effectiveName.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  /// 在 [text] 中高亮匹配 [query] 的部分
  Widget _highlightText(String text, String query, TextStyle baseStyle, Color highlightColor) {
    if (query.isEmpty) return Text(text, style: baseStyle);
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(lowerQ, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: baseStyle.copyWith(
            backgroundColor: highlightColor.withAlpha(80),
            color: highlightColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = idx + query.length;
    }
    return RichText(text: TextSpan(children: spans));
  }

  void _showDetailDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_iconRadius),
              child: SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: _buildIconWidget(colorScheme),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(package.effectiveName, style: textTheme.titleLarge)),
          ],
        ),
        content: SingleChildScrollView(child: _PackageDetailContent(package: package)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              onUninstall();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('卸载'),
          ),
        ],
      ),
    );
  }

  /// 纯图标 Widget，供 Dialog 和列表复用
  Widget _buildIconWidget(ColorScheme colorScheme) {
    final iconPath = package.iconPath;
    if (iconPath != null) {
      if (iconPath.endsWith('.svg')) {
        return SvgPicture.file(
          File(iconPath),
          width: _iconSize,
          height: _iconSize,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _fallback(colorScheme),
        );
      } else {
        return Image.file(
          File(iconPath),
          width: _iconSize,
          height: _iconSize,
          fit: BoxFit.contain,
          errorBuilder: (context, e, st) => _fallback(colorScheme),
        );
      }
    }
    return _fallback(colorScheme);
  }

  Widget _buildIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_iconRadius),
      child: SizedBox(width: _iconSize, height: _iconSize, child: _buildIconWidget(colorScheme)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseTitle = TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface);
    return ListTile(
      onTap: isUninstalling ? null : () => _showDetailDialog(context),
      leading: _buildIcon(context),
      title: _highlightText(package.effectiveName, highlightQuery, baseTitle, colorScheme.primary),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PackageSourceChip(source: package.source),
          if (package.description.isNotEmpty)
            Text(
              package.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (package.installedVersion != null)
            Text(
              '版本: ${package.installedVersion}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
        ],
      ),
      trailing: isUninstalling
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              color: colorScheme.error,
              tooltip: '卸载',
              onPressed: onUninstall,
            ),
    );
  }
}

/// 软件包详细信息内容（独立 Widget，不使用全局函数返回 Widget）
class _PackageDetailContent extends StatelessWidget {
  const _PackageDetailContent({required this.package});

  final Package package;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = textTheme.bodySmall?.copyWith(color: colorScheme.outline);
    final valueStyle = textTheme.bodyMedium;

    final rows = <({String label, String value})>[
      (label: '来源', value: package.source == PackageSource.snap ? 'Snap Store' : 'APT / dpkg'),
      if (package.installedVersion != null) (label: '已安装版本', value: package.installedVersion!),
      if (package.version.isNotEmpty && package.version != package.installedVersion)
        (label: '版本', value: package.version),
      (label: '包名', value: package.name),
      if (package.section != null) (label: '分类', value: package.section!),
      if (package.size != null) (label: '大小', value: package.size!),
      if (package.description.isNotEmpty) (label: '描述', value: package.description),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(),
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label, style: labelStyle),
                const SizedBox(height: 2),
                Text(row.value, style: valueStyle),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PackageSourceChip extends StatelessWidget {
  const _PackageSourceChip({required this.source});

  final PackageSource source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSnap = source == PackageSource.snap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: isSnap ? colorScheme.tertiaryContainer : colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isSnap ? 'Snap' : 'APT',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isSnap ? colorScheme.onTertiaryContainer : colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
