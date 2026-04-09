import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class HistoryService {
  static const String _historyKey = 'scan_history_list';

  Future<void> saveScan(double vnd, double php) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyLogs = prefs.getStringList(_historyKey) ?? [];

    final newItem = HistoryItem(vndAmount: vnd, phpAmount: php, timestamp: DateTime.now());

    // Add to the top of the list
    historyLogs.insert(0, newItem.toJson());

    // Keep only the last 50 scans to save space
    if (historyLogs.length > 50) historyLogs = historyLogs.sublist(0, 50);

    await prefs.setStringList(_historyKey, historyLogs);
  }

  Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyLogs = prefs.getStringList(_historyKey) ?? [];

    return historyLogs.map((item) => HistoryItem.fromJson(item)).toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}