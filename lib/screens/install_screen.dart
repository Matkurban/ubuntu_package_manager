import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/app_image_controller.dart';
import '../controllers/deb_install_controller.dart';
import '../controllers/packages_controller.dart';
import '../widgets/app_image_tile.dart';
import '../widgets/operation_progress_dialog.dart';

class InstallScreen extends StatefulWidget {
  const InstallScreen({
    super.key,
    required this.debController,
    required this.appImageController,
    required this.packagesController,
  });

  final DebInstallController debController;
  final AppImageController appImageController;
  final PackagesController packagesController;

  @override
  State<InstallScreen> createState() => _InstallScreenState();
}

class _InstallScreenState extends State<InstallScreen> {
  @override
  void initState() {
    super.initState();
    widget.appImageController.loadAppImages();

    // 监听 deb 安装结果
    effect(() {
      final r = widget.debController.installResult.value;
      if (r != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          OperationResultDialog.show(
            context,
            success: r.success,
            message: r.message,
            title: r.success ? '安装成功' : '安装失败',
          );
          widget.debController.clearResult();
        });
      }
    });

    // 监听 deb pendingInstall → 显示确认对话框
    effect(() {
      final pending = widget.debController.pendingInstall.value;
      if (pending != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showDebConfirmDialog(pending);
        });
      }
    });

    // 监听 AppImage pendingAdd → 显示替换确认对话框
    effect(() {
      final pending = widget.appImageController.pendingAdd.value;
      if (pending != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showAppImageReplaceDialog(pending);
        });
      }
    });

    // 监听 AppImage 操作结果
    effect(() {
      final r = widget.appImageController.operationResult.value;
      if (r != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (r.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(r.message),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            OperationResultDialog.show(context, success: false, message: r.message);
          }
          widget.appImageController.operationResult.value = null;
        });
      }
    });
  }

  void _showDebConfirmDialog(DebPendingInstall pending) {
    // 查找已安装包的图标（按包名匹配）
    final installedPkg = pending.packageName != null
        ? widget.packagesController.packages.value
              .where((p) => p.name == pending.packageName)
              .firstOrNull
        : null;

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        Widget iconWidget;
        if (installedPkg?.iconPath != null) {
          final path = installedPkg!.iconPath!;
          if (path.endsWith('.svg')) {
            iconWidget = SvgPicture.file(
              File(path),
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => Icon(
                pending.isAlreadyInstalled ? Icons.update : Icons.install_desktop,
                size: 48,
                color: colorScheme.primary,
              ),
            );
          } else {
            iconWidget = Image.file(
              File(path),
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (context, e, st) => Icon(
                pending.isAlreadyInstalled ? Icons.update : Icons.install_desktop,
                size: 48,
                color: colorScheme.primary,
              ),
            );
          }
        } else {
          iconWidget = Icon(
            pending.isAlreadyInstalled ? Icons.update : Icons.install_desktop,
            size: 48,
            color: colorScheme.primary,
          );
        }

        return AlertDialog(
          icon: iconWidget,
          title: Text(pending.isAlreadyInstalled ? '替换已安装的软件包' : '确认安装'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('软件包：${pending.displayName}'),
              if (pending.isAlreadyInstalled && pending.installedVersion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('当前版本：${pending.installedVersion}'),
                ),
              if (pending.newVersion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    pending.isAlreadyInstalled
                        ? '新版本：${pending.newVersion}'
                        : '版本：${pending.newVersion}',
                  ),
                ),
              if (pending.isAlreadyInstalled)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('此操作将替换已安装版本，需要管理员权限。'),
                )
              else
                const Padding(padding: EdgeInsets.only(top: 12), child: Text('安装需要管理员权限（pkexec）。')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.debController.cancelPending();
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.debController.confirmInstall();
              },
              child: Text(pending.isAlreadyInstalled ? '替换' : '安装'),
            ),
          ],
        );
      },
    );
  }

  void _showAppImageReplaceDialog(AppImagePendingAdd pending) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.swap_horiz, size: 40, color: Theme.of(ctx).colorScheme.primary),
        title: const Text('AppImage 已存在'),
        content: Text('"${pending.name}" 已在管理列表中，是否用新文件替换？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.appImageController.cancelPendingAdd();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.appImageController.confirmAdd();
            },
            child: const Text('替换'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveAppImage(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "$name" 吗？'),
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
      await widget.appImageController.removeAppImage(id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 两张安装卡片（排成一行）──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // .deb 安装卡
              Expanded(
                child: Watch((context) {
                  final checking = widget.debController.isCheckingFile.value;
                  final installing = widget.debController.isInstalling.value;
                  final busy = checking || installing;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.archive_outlined, size: 40, color: colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            '.deb 软件包',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '安装 Debian 格式的本地软件包',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (busy)
                            Column(
                              children: [
                                const LinearProgressIndicator(),
                                const SizedBox(height: 8),
                                Text(
                                  checking ? '正在读取包信息…' : '正在安装，请在弹出窗口中授权…',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          else
                            FilledButton.icon(
                              onPressed: widget.debController.selectFile,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('安装 .deb 软件包'),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 12),
              // AppImage 添加卡
              Expanded(
                child: Watch((context) {
                  final loading = widget.appImageController.isLoading.value;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.apps_outlined, size: 40, color: colorScheme.secondary),
                          const SizedBox(height: 12),
                          Text(
                            'AppImage',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '添加并管理免安装的 AppImage 应用',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (loading)
                            const Center(child: CircularProgressIndicator())
                          else
                            FilledButton.icon(
                              onPressed: widget.appImageController.selectAndAddAppImage,
                              icon: const Icon(Icons.add),
                              label: const Text('添加 AppImage'),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: colorScheme.onSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── 已管理的 AppImage 列表 ──────────────────────────────
          Watch((context) {
            final appImages = widget.appImageController.appImages.value;
            if (appImages.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.list, size: 18, color: colorScheme.outline),
                      const SizedBox(width: 8),
                      Text(
                        '已管理的 AppImage（${appImages.length}）',
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...appImages.map(
                  (img) => AppImageTile(
                    appImage: img,
                    onLaunch: () =>
                        widget.appImageController.launchAppImage(img.managedPath, img.name),
                    onRemove: () => _confirmRemoveAppImage(img.id, img.name),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
