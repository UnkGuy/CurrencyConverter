import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FEATURE 1: Required for HapticFeedback (Vibration)
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../main.dart';
import '../../currency/services/currency_service.dart';

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

  bool _isFlashOn = false;

  // FEATURE 2: Track if the camera is paused
  bool _isFrozen = false;

  // FEATURE 1: Track the last found price so it doesn't vibrate continuously on the same number
  double? _lastVndPrice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRateAndStartCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      cameraController.stopImageStream();
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
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
        // FEATURE 2: Do not process frames if the screen is frozen!
        if (!_isProcessing && !_isFrozen) {
          _processCameraImage(image);
        }
      });
    }).catchError((e) {
      debugPrint('Camera Init Error: $e');
    });
  }

  void _toggleFlash() {
    if (_controller == null) return;
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  // FEATURE 2: Method to freeze/unfreeze the screen
  void _toggleFreeze() {
    setState(() {
      _isFrozen = !_isFrozen;
    });
    // Give a nice satisfying heavy bump when freezing
    if (_isFrozen) HapticFeedback.heavyImpact();
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
      if (mounted) _isProcessing = false;
    }
  }

  void _extractAndConvertPrice(String text) {
    if (_exchangeRate == null || text.isEmpty) return;

    final standardRegex = RegExp(r'\b\d{1,3}(?:[.,]\d{3})+\b');
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
      // FEATURE 1: Only vibrate if it's a NEW number!
      if (vndPrice != _lastVndPrice) {
        _lastVndPrice = vndPrice;
        HapticFeedback.lightImpact(); // The little vibration bump
      }

      double phpPrice = vndPrice * _exchangeRate!;
      setState(() {
        _displayText = "₱ ${phpPrice.toStringAsFixed(2)}";
      });
    }
  }

  // FEATURE 3: The Manual Entry Bottom Sheet
  void _showManualEntrySheet() {
    final TextEditingController textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows it to slide up above the keyboard
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Avoids keyboard overlap
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  "Manual Entry",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Enter VND (e.g., 150000)",
                  border: OutlineInputBorder(),
                  suffixText: "VND",
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () {
                    if (textController.text.isNotEmpty && _exchangeRate != null) {
                      // Try to parse what they typed safely
                      double? enteredVnd = double.tryParse(textController.text.replaceAll(',', ''));
                      if (enteredVnd != null) {
                        double phpPrice = enteredVnd * _exchangeRate!;
                        setState(() {
                          _displayText = "₱ ${phpPrice.toStringAsFixed(2)}";
                          _isFrozen = true; // Auto-freeze so the camera doesn't wipe out their manual entry
                        });
                        Navigator.pop(context); // Close the keyboard sheet
                      }
                    }
                  },
                  child: const Text("Convert", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
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
      // FEATURE 2: Wrapping the whole screen in a GestureDetector to catch taps
      body: GestureDetector(
        onTap: _toggleFreeze,
        child: Stack(
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
                  border: Border.all(
                    // Change border color to red if frozen
                      color: _isFrozen ? Colors.redAccent : Colors.greenAccent,
                      width: 3
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // FEATURE 2 UI: Show a "PAUSED" badge at the top if frozen
            if (_isFrozen)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "PAUSED - TAP TO RESUME",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

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
                child: Row(
                  children: [
                    // The Result Text
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          ),
                          if (_exchangeRate == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                "Warning: Connect to internet for rates.",
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            )
                        ],
                      ),
                    ),
                    // FEATURE 3 UI: The Manual Entry Keyboard Icon
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.keyboard, color: Colors.blueAccent),
                        onPressed: _showManualEntrySheet,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}