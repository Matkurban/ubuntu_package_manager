import 'dart:io';

import '../models/package.dart';
import '../utils/desktop_utils.dart';

class AptService {
  /// 获取显示在桌面启动器中的已安装应用（通过 .desktop 文件）
  Future<List<Package>> getInstalledPackages() async {
    final systemDir = Directory('/usr/share/applications');
    final home = Platform.environment['HOME'] ?? '';
    final userDir = Directory('$home/.local/share/applications');

    // 1. 收集所有 .desktop 文件路径
    final systemFiles = <String>[];
    final userFiles = <String>[];

    if (await systemDir.exists()) {
      await for (final entity in systemDir.list()) {
        if (entity is File && entity.path.endsWith('.desktop')) {
          systemFiles.add(entity.path);
        }
      }
    }
    if (await userDir.exists()) {
      await for (final entity in userDir.list()) {
        if (entity is File && entity.path.endsWith('.desktop')) {
          userFiles.add(entity.path);
        }
      }
    }

    // 2. 解析 .desktop 文件，过滤出可见的 Application 条目
    final List<_DesktopEntry> entries = [];
    for (final path in [...systemFiles, ...userFiles]) {
      try {
        final content = await File(path).readAsString();
        final info = parseDesktopEntry(content);
        if (info['Type'] != 'Application') continue;
        if (info['NoDisplay']?.toLowerCase() == 'true') continue;
        if (info['Hidden']?.toLowerCase() == 'true') continue;
        final name = info['Name'];
        if (name == null || name.isEmpty) continue;
        entries.add(
          _DesktopEntry(
            filePath: path,
            name: name,
            comment: info['Comment'] ?? '',
            iconName: info['Icon'],
            isSystem: path.startsWith('/usr/share/'),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    // 3. 通过 dpkg -S 批量获取系统文件对应的包名（分批处理避免参数过长）
    final systemPaths = entries.where((e) => e.isSystem).map((e) => e.filePath).toList();

    final Map<String, String> fileToPackage = {}; // filePath → pkgName
    for (int i = 0; i < systemPaths.length; i += 50) {
      final chunk = systemPaths.sublist(i, (i + 50).clamp(0, systemPaths.length));
      final result = await Process.run('dpkg', ['-S', ...chunk]);
      for (final line in (result.stdout as String).split('\n')) {
        final idx = line.indexOf(': ');
        if (idx <= 0) continue;
        final pkg = line.substring(0, idx).trim();
        final path = line.substring(idx + 2).trim();
        fileToPackage[path] = pkg;
      }
    }

    // 4. 批量获取包版本
    final packageNames = fileToPackage.values.toSet().toList();
    final Map<String, String> packageVersions = {};
    if (packageNames.isNotEmpty) {
      for (int i = 0; i < packageNames.length; i += 100) {
        final chunk = packageNames.sublist(i, (i + 100).clamp(0, packageNames.length));
        final result = await Process.run('dpkg-query', [
          '-W',
          '-f=\${Package}||||\${Version}\n',
          ...chunk,
        ]);
        for (final line in (result.stdout as String).split('\n')) {
          final parts = line.split('||||');
          if (parts.length == 2) {
            packageVersions[parts[0].trim()] = parts[1].trim();
          }
        }
      }
    }

    // 5. 并发解析所有条目的图标路径
    final iconPathList = await Future.wait(
      entries.map(
        (e) =>
            e.iconName != null ? resolveIconPath(e.iconName!, home) : Future<String?>.value(null),
      ),
    );

    // 6. 构建 Package 列表，按包名去重
    final Map<String, Package> seen = {};
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final pkgName = fileToPackage[entry.filePath];
      final key = pkgName ?? entry.name;
      if (seen.containsKey(key)) continue;
      seen[key] = Package(
        name: pkgName ?? entry.name.toLowerCase().replaceAll(' ', '-'),
        displayName: entry.name,
        iconPath: iconPathList[i],
        version: pkgName != null ? (packageVersions[pkgName] ?? '') : '',
        description: entry.comment,
        installedVersion: pkgName != null ? packageVersions[pkgName] : null,
        isInstalled: true,
        source: PackageSource.apt,
      );
    }

    final list = seen.values.toList();
    list.sort((a, b) => a.effectiveName.compareTo(b.effectiveName));
    return list;
  }

  /// 卸载软件包（通过 pkexec 提权）
  Future<ProcessResult> removePackage(String packageName) async {
    return Process.run('pkexec', ['apt-get', 'remove', '-y', packageName]);
  }
}

class _DesktopEntry {
  const _DesktopEntry({
    required this.filePath,
    required this.name,
    required this.comment,
    required this.isSystem,
    this.iconName,
  });
  final String filePath;
  final String name;
  final String comment;
  final bool isSystem;
  final String? iconName;
}
