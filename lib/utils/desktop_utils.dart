import 'dart:io';

/// 解析 .desktop 文件的 [Desktop Entry] 段，返回 key→value 映射。
Map<String, String> parseDesktopEntry(String content) {
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
      if (inEntry) break;
      continue;
    }
    if (!inEntry) continue;

    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    final value = line.substring(idx + 1).trim();
    if (!key.contains('[') && !result.containsKey(key)) {
      result[key] = value;
    }
  }
  return result;
}

/// 解析图标名称为绝对文件路径（仅 PNG/SVG，不支持 XPM）。
Future<String?> resolveIconPath(String iconName, String home) async {
  if (iconName.startsWith('/')) {
    if (await File(iconName).exists()) return iconName;
    return null;
  }

  final base = iconName.replaceAll(RegExp(r'\.(png|svg|xpm|ico)$', caseSensitive: false), '');

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
