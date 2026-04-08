import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
// Make sure to import your new service!
import 'features/currency/services/currency_service.dart';
import 'features/scanner/screens/scanner_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize the cameras
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Camera error: ${e.code}, ${e.description}');
  }

  // 2. Manage the Currency Rate in the background
  final currencyService = CurrencyService();
  final needsUpdate = await currencyService.isRateOutdated();

  if (needsUpdate) {
    debugPrint('Rate is missing or outdated. Fetching a new one...');
    await currencyService.fetchAndSaveRate();
  } else {
    debugPrint('Rate is fresh! Ready for offline use.');
  }

  // 3. Run the app
  runApp(const PriceScannerApp());
}

class PriceScannerApp extends StatelessWidget {
  const PriceScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Converter', // Updated to your new title!
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ScannerScreen(), // This tells the app to load your camera screen
    );
  }
}