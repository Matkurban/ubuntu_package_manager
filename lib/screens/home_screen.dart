import 'package:flutter/material.dart';

import '../controllers/app_image_controller.dart';
import '../controllers/deb_install_controller.dart';
import '../controllers/packages_controller.dart';
import 'install_screen.dart';
import 'packages_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.packagesController,
    required this.debInstallController,
    required this.appImageController,
  });

  final PackagesController packagesController;
  final DebInstallController debInstallController;
  final AppImageController appImageController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.apps_outlined),
      selectedIcon: Icon(Icons.apps),
      label: '已安装应用',
    ),
    NavigationDestination(
      icon: Icon(Icons.download_outlined),
      selectedIcon: Icon(Icons.download),
      label: '安装软件',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          PackagesScreen(controller: widget.packagesController),
          InstallScreen(
            debController: widget.debInstallController,
            appImageController: widget.appImageController,
            packagesController: widget.packagesController,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: _tabs,
      ),
    );
  }
}
