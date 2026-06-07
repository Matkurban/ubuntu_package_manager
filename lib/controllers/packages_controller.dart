import 'package:signals/signals_flutter.dart';

import '../models/package.dart';
import '../services/apt_service.dart';
import '../services/snap_service.dart';

class PackagesController {
  PackagesController({required this.aptService, required this.snapService});

  final AptService aptService;
  final SnapService snapService;

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
      final results = await Future.wait([
        aptService.getInstalledPackages(),
        snapService.getInstalledPackages(),
      ]);
      final merged = [...results[0], ...results[1]]
        ..sort((a, b) => a.effectiveName.toLowerCase().compareTo(b.effectiveName.toLowerCase()));
      _packages.value = merged;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> uninstallPackage(Package package) async {
    isLoading.value = true;
    uninstallResult.value = null;
    try {
      final result = package.source == PackageSource.snap
          ? await snapService.removePackage(package.name)
          : await aptService.removePackage(package.name);
      if (result.exitCode == 0) {
        _packages.value = _packages.value
            .where((p) => !(p.source == package.source && p.name == package.name))
            .toList();
        uninstallResult.value = (success: true, message: '已成功卸载 ${package.effectiveName}');
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
