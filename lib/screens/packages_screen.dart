import 'package:contact_list_view/contact_list_view.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/packages_controller.dart';
import '../models/package.dart';
import '../widgets/operation_progress_dialog.dart';
import '../widgets/package_tile.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key, required this.controller});

  final PackagesController controller;

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  late final TextEditingController _searchController;
  String? _uninstallingPackage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    widget.controller.loadPackages();

    // Show result dialog whenever uninstallResult changes
    effect(() {
      final r = widget.controller.uninstallResult.value;
      if (r != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _uninstallingPackage = null;
            OperationResultDialog.show(
              context,
              success: r.success,
              message: r.message,
              title: r.success ? '卸载成功' : '卸载失败',
            );
            widget.controller.uninstallResult.value = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _tagOf(Package pkg) {
    final name = pkg.effectiveName.trim();
    if (name.isEmpty) return '#';
    final first = name[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
  }

  Future<void> _confirmUninstall(String packageName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认卸载'),
        content: Text('确定要卸载 "$packageName" 吗？此操作需要管理员权限。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('卸载'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _uninstallingPackage = packageName);
      await widget.controller.uninstallPackage(packageName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SearchBar(
            controller: _searchController,
            hintText: '搜索已安装软件包...',
            leading: const Icon(Icons.search),
            trailing: [
              Watch((context) {
                final q = widget.controller.searchQuery.value;
                if (q.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    widget.controller.searchQuery.value = '';
                  },
                );
              }),
              Watch((context) {
                final loading = widget.controller.isLoading.value;
                return IconButton(
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '刷新列表',
                  onPressed: loading ? null : widget.controller.loadPackages,
                );
              }),
            ],
            onChanged: (value) {
              widget.controller.searchQuery.value = value;
            },
          ),
        ),
        Expanded(
          child: Watch((context) {
            final isLoading = widget.controller.isLoading.value;
            final packages = widget.controller.filteredPackages.value;
            final error = widget.controller.error.value;

            if (isLoading && packages.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载已安装软件包...'),
                  ],
                ),
              );
            }

            if (error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text('加载失败: $error'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: widget.controller.loadPackages,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            if (packages.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    const Text('没有找到软件包'),
                  ],
                ),
              );
            }

            final sorted = [...packages]
              ..sort(
                (a, b) => a.effectiveName.toLowerCase().compareTo(b.effectiveName.toLowerCase()),
              );

            return RefreshIndicator(
              onRefresh: widget.controller.loadPackages,
              child: ContactListView<Package>(
                contactsList: sorted,
                tag: _tagOf,
                stickyHeaderPadding: const EdgeInsets.symmetric(horizontal: 24),
                itemBuilder: (pkg) => PackageTile(
                  package: pkg,
                  highlightQuery: widget.controller.searchQuery.value,
                  isUninstalling: _uninstallingPackage == pkg.name,
                  onUninstall: () => _confirmUninstall(pkg.name),
                ),
                stickyHeaderHeight: 32,
              ),
            );
          }),
        ),
      ],
    );
  }
}
