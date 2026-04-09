import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../main.dart';
import '../../currency/services/currency_service.dart';

// Import your brand new refactored pieces!
import '../logic/price_parser.dart';
import '../widgets/target_box.dart';
import '../widgets/result_panel.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  double? _exchangeRate;
  double? _lastVndPrice;
  String _displayText = "Point camera at a price";

  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isFrozen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRateAndStartCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller!.stopImageStream();
      _controller!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _loadRateAndStartCamera() async {
    final rate = await CurrencyService().getOfflineRate();
    setState(() => _exchangeRate = rate);
    _initializeCamera();
  }

  void _initializeCamera() {
    if (cameras.isEmpty) return;

    _controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
    _controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller!.startImageStream((CameraImage image) {
        if (!_isProcessing && !_isFrozen) _processCameraImage(image);
      });
    }).catchError((e) => debugPrint('Camera Init Error: $e'));
  }

  void _toggleFlash() {
    if (_controller == null) return;
    setState(() => _isFlashOn = !_isFlashOn);
    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _toggleFreeze() {
    setState(() => _isFrozen = !_isFrozen);
    if (_isFrozen) HapticFeedback.heavyImpact();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _isProcessing = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Look how clean this logic is now!
      if (_exchangeRate != null) {
        final vndPrice = PriceParser.extractPrice(recognizedText.text);

        if (vndPrice != null) {
          if (vndPrice != _lastVndPrice) {
            _lastVndPrice = vndPrice;
            HapticFeedback.lightImpact();
          }
          double phpPrice = vndPrice * _exchangeRate!;
          setState(() {
            _displayText = "₱ ${phpPrice.toStringAsFixed(2)}";
          });
        }
      }
    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _isProcessing = false;
    }
  }

  void _showManualEntrySheet() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Manual Entry", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: "Enter VND", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () {
                    if (textController.text.isNotEmpty && _exchangeRate != null) {
                      double? enteredVnd = double.tryParse(textController.text.replaceAll(',', ''));
                      if (enteredVnd != null) {
                        double phpPrice = enteredVnd * _exchangeRate!;
                        setState(() {
                          _displayText = "₱ ${phpPrice.toStringAsFixed(2)}";
                          _isFrozen = true;
                        });
                        Navigator.pop(context);
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
    for (final Plane plane in image.planes) allBytes.putUint8List(plane.bytes);
    final bytes = allBytes.done().buffer.asUint8List();
    final imageMetadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
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
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleFreeze,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller!),

            // Replaced 40 lines of code with one clean widget call
            TargetBox(isFrozen: _isFrozen),

            Positioned(
              top: 60,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: Colors.white.withOpacity(0.8),
                onPressed: _toggleFlash,
                child: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.black),
              ),
            ),

            // Replaced 50 lines of code with one clean widget call
            ResultPanel(
              displayText: _displayText,
              hasExchangeRate: _exchangeRate != null,
              onManualEntryTap: _showManualEntrySheet,
            ),
          ],
        ),
      ),
    );
  }
}