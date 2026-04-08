import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../main.dart'; // To access the global 'cameras' list
import '../../currency/services/currency_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;

  // --- NEW: App State Variables ---
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  double? _exchangeRate;
  String _displayText = "Point camera at a price";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadRateAndStartCamera();
  }

  // --- NEW: Load the offline rate before starting the camera ---
  Future<void> _loadRateAndStartCamera() async {
    final rate = await CurrencyService().getOfflineRate();
    setState(() {
      _exchangeRate = rate;
    });
    _initializeCamera();
  }

  void _initializeCamera() {
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false, // We don't need audio for this!
    );

    _controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});

      // We will start the image stream here in Phase 2!

    }).catchError((e) {
      debugPrint('Camera Init Error: $e');
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close(); // ALWAYS close the recognizer to save battery
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The Live Camera Feed
          CameraPreview(_controller!),

          // 2. The UI Overlay (Darkened edges with a clear center target)
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                // The Target Box
                Center(
                  child: Container(
                    height: 100,
                    width: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. The Target Box Border (So it looks nice)
          Center(
            child: Container(
              height: 100,
              width: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // 4. The Result Display Panel
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Converted to PHP (₱)",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _displayText,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_exchangeRate == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Warning: No exchange rate found. Connect to internet.",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}