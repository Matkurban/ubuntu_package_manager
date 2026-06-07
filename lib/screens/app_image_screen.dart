import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/app_image_controller.dart';
import '../widgets/app_image_tile.dart';
import '../widgets/operation_progress_dialog.dart';

class AppImageScreen extends SignalStatefulWidget {
  const AppImageScreen({super.key, required this.controller});

  final AppImageController controller;

  @override
  State<AppImageScreen> createState() => _AppImageScreenState();
}

class _AppImageScreenState extends State<AppImageScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadAppImages();

    effect(() {
      final r = widget.controller.operationResult.value;
      if (r != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Only show dialog for failures or explicit success notifications
            if (!r.success) {
              OperationResultDialog.show(context, success: r.success, message: r.message);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(r.message),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            widget.controller.operationResult.value = null;
          }
        });
      }
    });
  }

  Future<void> _confirmRemove(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "$name" 吗？这将删除托管目录中的 AppImage 文件。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.removeAppImage(id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final isLoading = widget.controller.isLoading.value;
        final appImages = widget.controller.appImages.value;
        final error = widget.controller.error.value;

        if (isLoading && appImages.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在加载 AppImage 列表...'),
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
                  onPressed: widget.controller.loadAppImages,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (appImages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apps_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                const Text('暂无 AppImage', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('点击右下角 + 按钮添加 AppImage 文件', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: widget.controller.loadAppImages,
          child: ListView.builder(
            itemCount: appImages.length,
            itemBuilder: (context, index) {
              final img = appImages[index];
              return AppImageTile(
                appImage: img,
                onLaunch: () => widget.controller.launchAppImage(img.managedPath, img.name),
                onRemove: () => _confirmRemove(img.id, img.name),
              );
            },
          ),
        );
      },
    );
  }
}
