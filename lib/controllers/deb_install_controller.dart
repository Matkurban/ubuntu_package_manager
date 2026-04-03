import 'package:file_selector/file_selector.dart';
import 'package:signals/signals_flutter.dart';

import '../services/deb_service.dart';

class DebPendingInstall {
  const DebPendingInstall({
    required this.filePath,
    required this.fileName,
    this.packageName,
    this.installedVersion,
    this.newVersion,
  });

  final String filePath;
  final String fileName;
  final String? packageName;

  /// 当前系统已安装版本，null 表示未安装
  final String? installedVersion;

  /// .deb 文件中的版本
  final String? newVersion;

  bool get isAlreadyInstalled => installedVersion != null;

  String get displayName => packageName ?? fileName;
}

class DebInstallController {
  DebInstallController({required this.debService});

  final DebService debService;

  /// 选文件 + 检测后，等待用户确认的状态；null 表示无待处理安装
  final pendingInstall = signal<DebPendingInstall?>(null);
  final isCheckingFile = signal(false);
  final isInstalling = signal(false);
  final installResult = signal<({bool success, String message})?>(null);

  /// 打开文件选择器，检测是否已安装，结果写入 pendingInstall。
  Future<void> selectFile() async {
    installResult.value = null;
    const typeGroup = XTypeGroup(label: 'Debian Package', extensions: ['deb']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    isCheckingFile.value = true;
    try {
      final String? pkgName = await debService.getPackageNameFromDeb(file.path);
      final String? newVersion = await debService.getDebVersion(file.path);
      final String? installedVersion = pkgName != null
          ? await debService.getInstalledVersion(pkgName)
          : null;

      pendingInstall.value = DebPendingInstall(
        filePath: file.path,
        fileName: file.name,
        packageName: pkgName,
        installedVersion: installedVersion,
        newVersion: newVersion,
      );
    } catch (e) {
      installResult.value = (success: false, message: '读取文件失败: $e');
    } finally {
      isCheckingFile.value = false;
    }
  }

  /// 用户确认后执行安装。
  Future<void> confirmInstall() async {
    final pending = pendingInstall.value;
    if (pending == null) return;

    pendingInstall.value = null;
    isInstalling.value = true;
    try {
      final (exitCode, stdout, stderr) = await debService.installDeb(pending.filePath);
      if (exitCode == 0) {
        installResult.value = (success: true, message: '已成功安装 ${pending.displayName}');
      } else {
        installResult.value = (
          success: false,
          message: stderr.trim().isNotEmpty ? stderr.trim() : '安装失败，退出码: $exitCode',
        );
      }
    } catch (e) {
      installResult.value = (success: false, message: e.toString());
    } finally {
      isInstalling.value = false;
    }
  }

  void cancelPending() => pendingInstall.value = null;
  void clearResult() => installResult.value = null;
}
