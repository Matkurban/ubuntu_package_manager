import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/app_image_controller.dart';
import 'controllers/deb_install_controller.dart';
import 'controllers/packages_controller.dart';
import 'services/app_image_service.dart';
import 'services/apt_service.dart';
import 'services/deb_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final aptService = AptService();
  final debService = DebService();
  final appImageService = AppImageService();

  final packagesController = PackagesController(aptService: aptService);
  final debInstallController = DebInstallController(debService: debService);
  final appImageController = AppImageController(appImageService: appImageService);

  runApp(
    App(
      packagesController: packagesController,
      debInstallController: debInstallController,
      appImageController: appImageController,
    ),
  );
}
