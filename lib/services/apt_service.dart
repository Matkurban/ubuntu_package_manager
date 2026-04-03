import 'dart:io';
import '../models/package.dart';

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
        final info = _parseDesktopEntry(content);
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
            e.iconName != null ? _resolveIconPath(e.iconName!, home) : Future<String?>.value(null),
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

/// 解析 .desktop 文件的 [Desktop Entry] 段，返回 key→value 映射。
Map<String, String> _parseDesktopEntry(String content) {
  final Map<String, String> result = {};
  bool inEntry = false;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    if (line == '[Desktop Entry]') {
      inEntry = true;
      continue;
    }
    if (line.startsWith('[')) {
      if (inEntry) break; // 遇到下一个 section 则停止
      continue;
    }
    if (!inEntry) continue;

    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    final value = line.substring(idx + 1).trim();
    // 只存无本地化后缀的 key，先出现者优先
    if (!key.contains('[') && !result.containsKey(key)) {
      result[key] = value;
    }
  }
  return result;
}

/// 解析图标名称为绝对文件路径（仅 PNG/SVG，不支持 XPM）。
/// 按质量优先级依次检查常见图标主题目录。
Future<String?> _resolveIconPath(String iconName, String home) async {
  // 已是绝对路径
  if (iconName.startsWith('/')) {
    if (await File(iconName).exists()) return iconName;
    return null;
  }

  // 去掉可能携带的扩展名
  final base = iconName.replaceAll(RegExp(r'\.(png|svg|xpm|ico)$', caseSensitive: false), '');

  // 候选路径：hicolor > Yaru（Ubuntu 默认主题）> pixmaps，大图优先
  final candidates = [
    '/usr/share/icons/hicolor/256x256/apps/$base.png',
    '/usr/share/icons/hicolor/128x128/apps/$base.png',
    '/usr/share/icons/hicolor/64x64/apps/$base.png',
    '/usr/share/icons/hicolor/48x48/apps/$base.png',
    '/usr/share/icons/Yaru/256x256/apps/$base.png',
    '/usr/share/icons/Yaru/48x48/apps/$base.png',
    '/usr/share/icons/hicolor/scalable/apps/$base.svg',
    '/usr/share/icons/Yaru/scalable/apps/$base.svg',
    '/usr/share/pixmaps/$base.png',
    '/usr/share/pixmaps/$base.svg',
    '$home/.local/share/icons/hicolor/256x256/apps/$base.png',
    '$home/.local/share/icons/hicolor/scalable/apps/$base.svg',
  ];

  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return null;
}
