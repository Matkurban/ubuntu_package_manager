import 'package:flutter/material.dart';
import 'package:ubuntu_package_manager/config/app_theme.dart';

import 'controllers/app_image_controller.dart';
import 'controllers/deb_install_controller.dart';
import 'controllers/packages_controller.dart';
import 'routing/routes.dart';
import 'screens/home_screen.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    required this.packagesController,
    required this.debInstallController,
    required this.appImageController,
  });

  final PackagesController packagesController;
  final DebInstallController debInstallController;
  final AppImageController appImageController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ubuntu Package Manager',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute: Routes.home,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case Routes.home:
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => HomeScreen(
                packagesController: packagesController,
                debInstallController: debInstallController,
                appImageController: appImageController,
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Center(child: Text('Page not found'))),
            );
        }
      },
    );
  }
}
