import 'package:flutter/material.dart';

class TargetBox extends StatelessWidget {
  final bool isFrozen;

  const TargetBox({super.key, required this.isFrozen});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The Darkened Overlay
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

        // The Red/Green Border
        Center(
          child: Container(
            height: 100,
            width: 250,
            decoration: BoxDecoration(
              border: Border.all(
                  color: isFrozen ? Colors.redAccent : Colors.greenAccent,
                  width: 3
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // The "PAUSED" Badge
        if (isFrozen)
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
      ],
    );
  }
}