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

  String _formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // FEATURE 1: Calculate Today's Total Spending!
  double get _todayTotal {
    final now = DateTime.now();
    return _history.where((item) =>
    item.timestamp.year == now.year &&
        item.timestamp.month == now.month &&
        item.timestamp.day == now.day
    ).fold(0.0, (sum, item) => sum + item.phpAmount);
  }

  // FEATURE 3: The Safety Net Confirmation Dialog
  Future<void> _confirmDeleteAll() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All History?"),
        content: const Text("This will permanently delete all saved scans. Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HistoryService().clearHistory();
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All history cleared.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _history.isEmpty ? null : _confirmDeleteAll, // Disable if already empty
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // FEATURE 1: The Daily Total Banner
          Container(
            width: double.infinity,
            color: Colors.blueAccent.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Total:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                Text(
                  "₱ ${_todayTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ],
            ),
          ),

          // The actual list of scans
          Expanded(
            child: _history.isEmpty
                ? const Center(child: Text("No scans saved yet! Freeze a price to save it."))
                : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];

                return Dismissible(
                  key: Key(item.timestamp.toIso8601String()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    await HistoryService().deleteScan(index);
                    setState(() {
                      _history.removeAt(index); // Update UI immediately so the total updates!
                    });
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
          ),
        ],
      ),
    );
  }
}