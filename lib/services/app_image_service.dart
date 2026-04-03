import 'dart:convert';
import 'dart:io';

import '../models/app_image.dart';

class AppImageService {
  static const String _storageDir = '.local/share/AppImages';
  static const String _registryFile = 'registry.json';

  String get _storagePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/$_storageDir';
  }

  String get _registryPath => '$_storagePath/$_registryFile';

  Future<void> _ensureStorageDir() async {
    final dir = Directory(_storagePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<List<AppImage>> loadRegistry() async {
    await _ensureStorageDir();
    final file = File(_registryPath);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final List<dynamic> list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => AppImage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRegistry(List<AppImage> images) async {
    await _ensureStorageDir();
    final file = File(_registryPath);
    final content = jsonEncode(images.map((e) => e.toJson()).toList());
    await file.writeAsString(content);
  }

  /// Copies the AppImage to the managed directory, sets executable, saves to registry.
  Future<AppImage> addAppImage(String sourcePath) async {
    await _ensureStorageDir();

    final sourceFile = File(sourcePath);
    final fileName = sourceFile.uri.pathSegments.last;
    final name = fileName.replaceAll(RegExp(r'\.AppImage$', caseSensitive: false), '');
    final id = '${DateTime.now().millisecondsSinceEpoch}_$name';
    final managedPath = '$_storagePath/$fileName';

    // Copy file
    await sourceFile.copy(managedPath);

    // Make executable
    await Process.run('chmod', ['+x', managedPath]);

    final appImage = AppImage(
      id: id,
      name: name,
      managedPath: managedPath,
      addedAt: DateTime.now(),
    );

    final current = await loadRegistry();
    await _saveRegistry([...current, appImage]);

    return appImage;
  }

  /// Deletes the managed file and removes it from the registry.
  Future<void> removeAppImage(String id) async {
    final current = await loadRegistry();
    final target = current.where((a) => a.id == id).firstOrNull;
    if (target != null) {
      final file = File(target.managedPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _saveRegistry(current.where((a) => a.id != id).toList());
  }

  /// Launches an AppImage in the background.
  Future<void> launchAppImage(String managedPath) async {
    await Process.start(managedPath, [], mode: ProcessStartMode.detached);
  }
}
