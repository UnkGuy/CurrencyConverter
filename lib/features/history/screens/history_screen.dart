import 'package:flutter/material.dart';
import '../models/history_item.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService().getHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  // Helper to format the date nicely
  String _formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // ... [Keep everything above the build method exactly the same!] ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await HistoryService().clearHistory();
              _loadHistory();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? const Center(child: Text("No scans saved yet! Freeze a price to save it."))
          : ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];

          // FEATURE 2: Wrap the ListTile in a Dismissible
          return Dismissible(
            key: Key(item.timestamp.toIso8601String()), // Unique ID for Flutter to track
            direction: DismissDirection.endToStart, // Swipe right to left
            background: Container(
              color: Colors.redAccent,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) async {
              await HistoryService().deleteScan(index);
              // We don't need to call _loadHistory() here because the UI already removed it
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Scan deleted"), duration: Duration(seconds: 1))
              );
            },
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.blueAccent),
              title: Text("₱ ${item.phpAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text("${item.vndAmount.toStringAsFixed(0)} VND • ${_formatDate(item.timestamp)}"),
            ),
          );
        },
      ),
    );
  }
}