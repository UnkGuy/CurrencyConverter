import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../main.dart';
import '../../currency/services/currency_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  double? _exchangeRate;
  String _displayText = "Point camera at a price";

  // This acts as a traffic light so we don't crash the phone
  // by trying to process 60 frames per second!
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadRateAndStartCamera();
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

      // --- PHASE 2: Start the Live Stream ---
      _controller!.startImageStream((CameraImage image) {
        if (!_isProcessing) {
          _processCameraImage(image);
        }
      });

    }).catchError((e) {
      debugPrint('Camera Init Error: $e');
    });
  }

  // --- PHASE 2: Process the Frames ---
  Future<void> _processCameraImage(CameraImage image) async {
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      // 1. Read the text on the screen
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // 2. Look for the price and convert it
      _extractAndConvertPrice(recognizedText.text);

    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      // 3. Take a tiny breath before checking the next frame
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _isProcessing = false;
      }
    }
  }

  // --- PHASE 2: The Math and Extraction ---
  void _extractAndConvertPrice(String text) {
    if (_exchangeRate == null || text.isEmpty) return;

    // This Regex specifically hunts for numbers with thousands separators
    // Example: It will find "150,000" or "150.000" but ignore "Call 1234"
    final regex = RegExp(r'\b\d{1,3}(?:[.,]\d{3})+\b');
    final match = regex.firstMatch(text);

    if (match != null) {
      // We found a price! Let's clean out the commas/dots so Dart can do math
      String cleanNumber = match.group(0)!.replaceAll(',', '').replaceAll('.', '');
      double vndPrice = double.parse(cleanNumber);

      // Do the conversion!
      double phpPrice = vndPrice * _exchangeRate!;

      setState(() {
        // Display it beautifully with 2 decimal places
        _displayText = "₱ ${phpPrice.toStringAsFixed(2)}";
      });
    }
  }

  // --- Boilerplate: Translate Flutter Camera to ML Kit Format ---
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
    _controller?.stopImageStream();
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ... [Keep your exact build(BuildContext context) method from before here!] ...
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