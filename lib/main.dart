import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'features/currency/services/currency_service.dart';
import 'features/scanner/screens/scanner_screen.dart';
import 'features/onboarding/screens/welcome_screen.dart';
import 'core/utils/camera_permission_handler.dart';


List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Manage the Currency Rate in the background
  final currencyService = CurrencyService();
  if (await currencyService.isRateOutdated()) {
    await currencyService.fetchAndSaveRate();
  }

  // Check if we ALREADY have camera permission
  bool hasPermission = await CameraPermissionHandler.hasPermission();
  if (hasPermission) {
    try {
      cameras = await availableCameras();
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  runApp(PriceScannerApp(startWithScanner: hasPermission));
}

class PriceScannerApp extends StatelessWidget {
  final bool startWithScanner;
  const PriceScannerApp({super.key, required this.startWithScanner});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Converter',
      theme: ThemeData(primarySwatch: Colors.blue),
      // If we have permission, go to scanner. Otherwise, go to welcome screen!
      home: startWithScanner ? const ScannerScreen() : const WelcomeScreen(),
    );
  }
}