import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../main.dart';
import '../../currency/services/currency_service.dart';
import '../../history/services/history_service.dart';
import '../../history/screens/history_screen.dart';

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
  DateTime? _lastRateUpdate;
  double? _lastVndPrice;
  String _displayText = "Point camera at a price";

  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isFrozen = false;

  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  // NEW: State variables to track where the box is on the screen!
  Offset? _targetPosition;
  final Size _targetSize = const Size(250, 100);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRateDataAndCamera();
  }

  // NEW: Center the box when the screen first loads
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_targetPosition == null) {
      final size = MediaQuery.of(context).size;
      _targetPosition = Offset(
        (size.width - _targetSize.width) / 2,
        (size.height - _targetSize.height) / 2,
      );
    }
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

  Future<void> _loadRateDataAndCamera() async {
    final rate = await CurrencyService().getOfflineRate();
    final date = await CurrencyService().getLastFetchDate();
    setState(() {
      _exchangeRate = rate;
      _lastRateUpdate = date;
    });
    _initializeCamera();
  }

  Future<void> _manualRefreshRate() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching latest rates...")));
    await CurrencyService().fetchAndSaveRate();

    final rate = await CurrencyService().getOfflineRate();
    final date = await CurrencyService().getLastFetchDate();
    if (mounted) {
      setState(() {
        _exchangeRate = rate;
        _lastRateUpdate = date;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Exchange rate updated!")));
    }
  }

  void _initializeCamera() {
    if (cameras.isEmpty) return;

    _controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
    _controller!.initialize().then((_) async {
      if (!mounted) return;

      _maxAvailableZoom = await _controller!.getMaxZoomLevel();
      _minAvailableZoom = await _controller!.getMinZoomLevel();

      setState(() {});
      _controller!.startImageStream((CameraImage image) {
        if (!_isProcessing && !_isFrozen) _processCameraImage(image);
      });
    }).catchError((Object e) {
      debugPrint('Camera Init Error: $e');
    });
  }

  void _toggleFlash() {
    if (_controller == null) return;
    setState(() => _isFlashOn = !_isFlashOn);
    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _toggleFreeze() {
    setState(() => _isFrozen = !_isFrozen);
    if (_isFrozen) {
      HapticFeedback.heavyImpact();
      if (_lastVndPrice != null && _exchangeRate != null) {
        HistoryService().saveScan(_lastVndPrice!, _lastVndPrice! * _exchangeRate!);

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Price saved to History!"),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            )
        );
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _isProcessing = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (_exchangeRate != null) {
        // Our new parser aggressively finds '50k/bát' and '50000'
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
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
                        HistoryService().saveScan(enteredVnd, phpPrice);
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
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
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

        onDoubleTap: () async {
          if (_controller != null && !_isFrozen) {
            await _controller!.setFocusPoint(const Offset(0.5, 0.5));
            HapticFeedback.mediumImpact();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Camera focused!"),
                    duration: Duration(milliseconds: 800),
                    behavior: SnackBarBehavior.floating,
                  )
              );
            }
          }
        },

        onScaleStart: (details) {
          _baseZoomLevel = _currentZoomLevel;
        },
        onScaleUpdate: (details) async {
          if (_controller == null || _isFrozen) return;
          _currentZoomLevel = (_baseZoomLevel * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
          await _controller!.setZoomLevel(_currentZoomLevel);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller!),

            // NEW: The target box is now fully movable!
            TargetBox(
              isFrozen: _isFrozen,
              position: _targetPosition ?? const Offset(50, 200),
              size: _targetSize,
              onPanUpdate: (details) {
                if (_isFrozen) return; // Lock the box in place if paused
                setState(() {
                  // This complex math ensures you can't drag the box off the screen!
                  _targetPosition = Offset(
                    (_targetPosition!.dx + details.delta.dx).clamp(0.0, MediaQuery.of(context).size.width - _targetSize.width),
                    (_targetPosition!.dy + details.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - _targetSize.height),
                  );
                });
              },
            ),

            Positioned(
              top: 60,
              left: 20,
              child: FloatingActionButton(
                heroTag: "history_btn",
                backgroundColor: Colors.white.withValues(alpha: 0.8),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                },
                child: const Icon(Icons.history, color: Colors.black),
              ),
            ),

            Positioned(
              top: 60,
              right: 20,
              child: FloatingActionButton(
                heroTag: "flash_btn",
                backgroundColor: Colors.white.withValues(alpha: 0.8),
                onPressed: _toggleFlash,
                child: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.black),
              ),
            ),

            ResultPanel(
              displayText: _displayText,
              hasExchangeRate: _exchangeRate != null,
              lastUpdate: _lastRateUpdate,
              onManualEntryTap: _showManualEntrySheet,
              onRefreshRate: _manualRefreshRate,
            ),
          ],
        ),
      ),
    );
  }
}