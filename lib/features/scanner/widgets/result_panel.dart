import 'package:flutter/material.dart';

class ResultPanel extends StatelessWidget {
  final String displayText;
  final bool hasExchangeRate;
  final VoidCallback onManualEntryTap;

  const ResultPanel({
    super.key,
    required this.displayText,
    required this.hasExchangeRate,
    required this.onManualEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
                    displayText,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                    ),
                  ),
                  if (!hasExchangeRate)
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
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.keyboard, color: Colors.blueAccent),
                onPressed: onManualEntryTap,
              ),
            )
          ],
        ),
      ),
    );
  }
}