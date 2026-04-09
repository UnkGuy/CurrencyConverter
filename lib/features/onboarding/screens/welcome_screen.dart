import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/utils/camera_permission_handler.dart';
import '../../scanner/screens/scanner_screen.dart';
import '../../../main.dart'; // To access the global 'cameras' variable

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _handlePermissionRequest(BuildContext context) async {
    final granted = await CameraPermissionHandler.requestPermission();

    if (granted) {
      // If granted, load the cameras and move to the scanner!
      cameras = await availableCameras();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        );
      }
    } else {
      // If denied, show a gentle prompt to open settings
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Camera access is required to scan prices."),
            action: SnackBarAction(
              label: "Settings",
              onPressed: CameraPermissionHandler.openSettings,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Spacer(), // Pushes the main content to the middle
              const Icon(Icons.camera_alt_outlined, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 32),
              const Text(
                "Welcome to\nCurrency Converter",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "To instantly translate physical prices into PHP, we need permission to use your camera. We process everything offline!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  onPressed: () => _handlePermissionRequest(context),
                  child: const Text("Enable Camera", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const Spacer(), // Pushes the signature to the very bottom

              // --- YOUR PERSONAL SIGNATURE ---
              const Text(
                "Made with ❤️ by Hans Baron\nfor the Baron Family",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic
                ),
              ),
              const SizedBox(height: 16), // A little breathing room at the bottom
            ],
          ),
        ),
      ),
    );
  }
}