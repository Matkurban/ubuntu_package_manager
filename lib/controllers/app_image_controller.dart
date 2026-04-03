import 'package:file_selector/file_selector.dart';
import 'package:signals/signals_flutter.dart';

import '../models/app_image.dart';
import '../services/app_image_service.dart';

class AppImagePendingAdd {
  const AppImagePendingAdd({required this.sourcePath, required this.name, this.existingId});

  final String sourcePath;
  final String name;

  /// 非 null 表示注册表中已存在同名 AppImage，需要替换
  final String? existingId;

  bool get isDuplicate => existingId != null;
}

class AppImageController {
  AppImageController({required this.appImageService});

  final AppImageService appImageService;

  final _appImages = signal<List<AppImage>>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);
  final operationResult = signal<({bool success, String message})?>(null);

  /// 等待用户确认替换；null 表示无待处理操作
  final pendingAdd = signal<AppImagePendingAdd?>(null);

  ReadonlySignal<List<AppImage>> get appImages => _appImages;

  Future<void> loadAppImages() async {
    isLoading.value = true;
    error.value = null;
    try {
      final list = await appImageService.loadRegistry();
      _appImages.value = list;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// 打开文件选择器，检测重名，直接添加或写入 pendingAdd 等待确认。
  Future<void> selectAndAddAppImage() async {
    operationResult.value = null;
    const typeGroup = XTypeGroup(label: 'AppImage', extensions: ['AppImage', 'appimage']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final sourcePath = file.path;
    final fileName = sourcePath.split('/').last;
    if (!fileName.toLowerCase().endsWith('.appimage')) {
      operationResult.value = (success: false, message: '所选文件不是 AppImage（需以 .AppImage 结尾）');
      return;
    }

    final name = fileName.replaceAll(RegExp(r'\.AppImage$', caseSensitive: false), '');

    // 检测注册表中是否已有同名 AppImage
    final existing = _appImages.value
        .where((a) => a.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;

    if (existing != null) {
      pendingAdd.value = AppImagePendingAdd(
        sourcePath: sourcePath,
        name: name,
        existingId: existing.id,
      );
      return;
    }

    await _doAdd(sourcePath);
  }

  /// 用户确认替换后调用。
  Future<void> confirmAdd() async {
    final pending = pendingAdd.value;
    if (pending == null) return;
    pendingAdd.value = null;

    if (pending.existingId != null) {
      // 先删除旧文件
      try {
        await appImageService.removeAppImage(pending.existingId!);
        _appImages.value = _appImages.value.where((a) => a.id != pending.existingId).toList();
      } catch (_) {}
    }

    await _doAdd(pending.sourcePath);
  }

  void cancelPendingAdd() => pendingAdd.value = null;

  Future<void> removeAppImage(String id, String name) async {
    isLoading.value = true;
    operationResult.value = null;
    try {
      await appImageService.removeAppImage(id);
      _appImages.value = _appImages.value.where((a) => a.id != id).toList();
      operationResult.value = (success: true, message: '已删除 $name');
    } catch (e) {
      operationResult.value = (success: false, message: e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> launchAppImage(String managedPath, String name) async {
    operationResult.value = null;
    try {
      await appImageService.launchAppImage(managedPath);
      operationResult.value = (success: true, message: '已启动 $name');
    } catch (e) {
      operationResult.value = (success: false, message: e.toString());
    }
  }

  Future<void> _doAdd(String sourcePath) async {
    isLoading.value = true;
    try {
      final appImage = await appImageService.addAppImage(sourcePath);
      _appImages.value = [..._appImages.value, appImage];
      operationResult.value = (success: true, message: '已成功添加 ${appImage.name}');
    } catch (e) {
      operationResult.value = (success: false, message: e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
