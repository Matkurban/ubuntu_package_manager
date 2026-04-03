import 'package:signals/signals_flutter.dart';

import '../models/package.dart';
import '../services/apt_service.dart';

class PackagesController {
  PackagesController({required this.aptService});

  final AptService aptService;

  final _packages = signal<List<Package>>([]);
  final isLoading = signal(false);
  final searchQuery = signal('');
  final error = signal<String?>(null);
  final uninstallResult = signal<({bool success, String message})?>(null);

  late final filteredPackages = computed<List<Package>>(() {
    final q = searchQuery.value.toLowerCase().trim();
    if (q.isEmpty) return _packages.value;
    return _packages.value
        .where(
          (p) =>
              p.effectiveName.toLowerCase().contains(q) ||
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q),
        )
        .toList();
  });

  ReadonlySignal<List<Package>> get packages => _packages;

  Future<void> loadPackages() async {
    isLoading.value = true;
    error.value = null;
    try {
      final list = await aptService.getInstalledPackages();
      _packages.value = list;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> uninstallPackage(String name) async {
    isLoading.value = true;
    uninstallResult.value = null;
    try {
      final result = await aptService.removePackage(name);
      if (result.exitCode == 0) {
        _packages.value = _packages.value.where((p) => p.name != name).toList();
        uninstallResult.value = (success: true, message: '已成功卸载 $name');
      } else {
        uninstallResult.value = (
          success: false,
          message: (result.stderr as String).trim().isNotEmpty
              ? result.stderr as String
              : '卸载失败，退出码: ${result.exitCode}',
        );
      }
    } catch (e) {
      uninstallResult.value = (success: false, message: e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
