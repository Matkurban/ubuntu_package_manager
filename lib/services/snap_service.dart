import 'dart:io';

import '../models/package.dart';
import '../utils/desktop_utils.dart';

class SnapService {
  static const _desktopDir = '/var/lib/snapd/desktop/applications';

  /// 获取已安装的 Snap GUI 应用（通过 snap desktop 文件）
  Future<List<Package>> getInstalledPackages() async {
    final snapVersions = await _fetchSnapVersions();
    if (snapVersions.isEmpty) return [];

    final desktopDir = Directory(_desktopDir);
    if (!await desktopDir.exists()) return [];

    final desktopFiles = <String>[];
    await for (final entity in desktopDir.list()) {
      if (entity is File && entity.path.endsWith('.desktop')) {
        desktopFiles.add(entity.path);
      }
    }

    final List<_SnapDesktopEntry> entries = [];
    for (final path in desktopFiles) {
      try {
        final content = await File(path).readAsString();
        final info = parseDesktopEntry(content);
        if (info['Type'] != 'Application') continue;
        if (info['NoDisplay']?.toLowerCase() == 'true') continue;
        if (info['Hidden']?.toLowerCase() == 'true') continue;
        final name = info['Name'];
        if (name == null || name.isEmpty) continue;
        final snapName = info['X-SnapInstanceName'];
        if (snapName == null || snapName.isEmpty) continue;
        if (!snapVersions.containsKey(snapName)) continue;
        entries.add(
          _SnapDesktopEntry(
            snapName: snapName,
            name: name,
            comment: info['Comment'] ?? '',
            iconName: info['Icon'],
          ),
        );
      } catch (_) {
        continue;
      }
    }

    final home = Platform.environment['HOME'] ?? '';
    final iconPathList = await Future.wait(
      entries.map(
        (e) =>
            e.iconName != null ? resolveIconPath(e.iconName!, home) : Future<String?>.value(null),
      ),
    );

    final Map<String, Package> seen = {};
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (seen.containsKey(entry.snapName)) continue;
      final version = snapVersions[entry.snapName] ?? '';
      seen[entry.snapName] = Package(
        name: entry.snapName,
        displayName: entry.name,
        iconPath: iconPathList[i],
        version: version,
        description: entry.comment,
        installedVersion: version,
        isInstalled: true,
        source: PackageSource.snap,
      );
    }

    final list = seen.values.toList();
    list.sort((a, b) => a.effectiveName.compareTo(b.effectiveName));
    return list;
  }

  /// 卸载 Snap 应用（通过 pkexec 提权）
  Future<ProcessResult> removePackage(String snapName) async {
    return Process.run('pkexec', ['snap', 'remove', snapName]);
  }

  Future<Map<String, String>> _fetchSnapVersions() async {
    try {
      final result = await Process.run('snap', ['list']);
      if (result.exitCode != 0) return {};
      return _parseSnapList(result.stdout as String);
    } catch (_) {
      return {};
    }
  }

  Map<String, String> _parseSnapList(String stdout) {
    final versions = <String, String>{};
    final lines = stdout.split('\n');
    if (lines.length <= 1) return versions;

    for (final line in lines.skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      versions[parts[0]] = parts[1];
    }
    return versions;
  }
}

class _SnapDesktopEntry {
  const _SnapDesktopEntry({
    required this.snapName,
    required this.name,
    required this.comment,
    this.iconName,
  });

  final String snapName;
  final String name;
  final String comment;
  final String? iconName;
}
