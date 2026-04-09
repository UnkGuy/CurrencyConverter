import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard

class ResultPanel extends StatelessWidget {
  final String displayText;
  final bool hasExchangeRate;
  final DateTime? lastUpdate;
  final VoidCallback onManualEntryTap;
  final VoidCallback onRefreshRate;

  const ResultPanel({
    super.key,
    required this.displayText,
    required this.hasExchangeRate,
    required this.lastUpdate,
    required this.onManualEntryTap,
    required this.onRefreshRate,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return "Unknown";
    final today = DateTime.now();
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final timeStr = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    return isToday ? "Today at $timeStr" : "${date.month}/${date.day}/${date.year}";
  }

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

                  // FEATURE 2: Copy to Clipboard Row
                  Row(
                    children: [
                      Text(
                        displayText,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      if (displayText != "Point camera at a price")
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: displayText));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Copied to clipboard!"), duration: Duration(seconds: 2))
                            );
                          },
                        )
                    ],
                  ),
                  const SizedBox(height: 8),

                  // FEATURE 3: Rate Freshness & Refresh Button
                  hasExchangeRate
                      ? Row(
                    children: [
                      const Icon(Icons.update, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("Updated: ${_formatDate(lastUpdate)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Spacer(),
                      InkWell(
                        onTap: onRefreshRate,
                        child: const Text("Refresh Rate", style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      )
                    ],
                  )
                      : const Text(
                    "Warning: Connect to internet for rates.",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  )
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
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