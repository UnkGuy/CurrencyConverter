import 'package:flutter/material.dart';

class TargetBox extends StatelessWidget {
  final bool isFrozen;
  final Offset position;
  final Size size;
  final Function(DragUpdateDetails) onPanUpdate;

  const TargetBox({
    super.key,
    required this.isFrozen,
    required this.position,
    required this.size,
    required this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The Darkened Overlay with the cutout hole
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
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
              Positioned(
                left: position.dx,
                top: position.dy,
                child: Container(
                  height: size.height,
                  width: size.width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // The Movable Border (This is what you grab and drag!)
        Positioned(
          left: position.dx,
          top: position.dy,
          child: GestureDetector(
            onPanUpdate: onPanUpdate,
            child: Container(
              height: size.height,
              width: size.width,
              decoration: BoxDecoration(
                color: Colors.transparent, // Must be transparent so you can drag the center
                border: Border.all(
                    color: isFrozen ? Colors.redAccent : Colors.greenAccent,
                    width: 3
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // The "PAUSED" Badge
        if (isFrozen)
          Positioned(
            top: position.dy - 50, // Hovers just above the moving box
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
      ],
    );
  }
}