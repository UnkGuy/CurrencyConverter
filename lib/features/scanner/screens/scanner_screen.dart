import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../main.dart';
import '../../currency/services/currency_service.dart';

// FEATURE 3: Adding 'WidgetsBindingObserver' lets the app know when it is minimized to save battery
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  double? _exchangeRate;
  String _displayText = "Point camera at a price";

  bool _isProcessing = false;

  // FEATURE 1: Flashlight state tracking
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    // FEATURE 3: Start listening to the app lifecycle (open vs minimized)
    WidgetsBinding.instance.addObserver(this);
    _loadRateAndStartCamera();
  }

  // FEATURE 3: Pause the camera if the user switches to another app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // App minimized: Stop the camera to save battery
      cameraController.stopImageStream();
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // App reopened: Turn the camera back on
      _initializeCamera();
    }
  }

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
      enableAudio: false,
    );

    _controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});

      _controller!.startImageStream((CameraImage image) {
        if (!_isProcessing) {
          _processCameraImage(image);
        }
      });

    }).catchError((e) {
      debugPrint('Camera Init Error: $e');
    });
  }

  // FEATURE 1: The method to turn the flashlight on and off
  void _toggleFlash() {
    if (_controller == null) return;
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);
      _extractAndConvertPrice(recognizedText.text);

    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _isProcessing = false;
      }
    }
  }

  // FEATURE 2: Smarter Vietnamese number parsing ("The 'K' Rule")
  void _extractAndConvertPrice(String text) {
    if (_exchangeRate == null || text.isEmpty) return;

    // 1. Look for standard numbers (150,000 or 150.000)
    final standardRegex = RegExp(r'\b\d{1,3}(?:[.,]\d{3})+\b');
    // 2. Look for the "k" abbreviation (15k, 150K, 50 k)
    final kRegex = RegExp(r'\b(\d{1,3})\s?[kK]\b');

    final standardMatch = standardRegex.firstMatch(text);
    final kMatch = kRegex.firstMatch(text);

    double? vndPrice;

    if (standardMatch != null) {
      String cleanNumber = standardMatch.group(0)!.replaceAll(',', '').replaceAll('.', '');
      vndPrice = double.parse(cleanNumber);
    } else if (kMatch != null) {
      String cleanNumber = kMatch.group(1)!;
      vndPrice = double.parse(cleanNumber) * 1000;
    }

    if (vndPrice != null) {
      double phpPrice = vndPrice * _exchangeRate!;
      setState(() {
        _displayText = "₱ ${phpPrice.toStringAsFixed(2)}";
      });
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = cameras[0];
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || (format != InputImageFormat.nv21 && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final imageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: imageMetadata);
  }

  @override
  void dispose() {
    // FEATURE 3: Stop listening to the app lifecycle when screen closes
    WidgetsBinding.instance.removeObserver(this);
    _controller?.stopImageStream();
    _controller?.dispose();
    _textRecognizer.close();
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
          CameraPreview(_controller!),

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

          // FEATURE 1: The Flashlight Button UI
          Positioned(
            top: 60,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white.withOpacity(0.8),
              onPressed: _toggleFlash,
              child: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.black,
              ),
            ),
          ),

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