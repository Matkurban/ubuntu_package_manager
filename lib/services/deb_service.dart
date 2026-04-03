import 'dart:io';

class DebService {
  /// 从 .deb 文件读取包名。
  Future<String?> getPackageNameFromDeb(String filePath) async {
    final result = await Process.run('dpkg-deb', ['--field', filePath, 'Package']);
    if (result.exitCode != 0) return null;
    final v = (result.stdout as String).trim();
    return v.isNotEmpty ? v : null;
  }

  /// 从 .deb 文件读取版本号。
  Future<String?> getDebVersion(String filePath) async {
    final result = await Process.run('dpkg-deb', ['--field', filePath, 'Version']);
    if (result.exitCode != 0) return null;
    final v = (result.stdout as String).trim();
    return v.isNotEmpty ? v : null;
  }

  /// 查询系统中已安装的版本，未安装则返回 null。
  Future<String?> getInstalledVersion(String packageName) async {
    final result = await Process.run('dpkg-query', [
      '-W',
      '-f=\${db:Status-Status}\t\${Version}',
      packageName,
    ]);
    if (result.exitCode != 0) return null;
    final parts = (result.stdout as String).trim().split('\t');
    if (parts.length != 2 || parts[0].trim() != 'installed') return null;
    return parts[1].trim();
  }

  /// 使用 pkexec dpkg -i 安装 .deb 包，返回 (exitCode, stdout, stderr)。
  Future<(int, String, String)> installDeb(String filePath) async {
    final result = await Process.run('pkexec', ['dpkg', '-i', filePath]);
    return (result.exitCode, result.stdout as String, result.stderr as String);
  }
}
