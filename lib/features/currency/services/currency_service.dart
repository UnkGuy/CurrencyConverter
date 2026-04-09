import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const String _apiUrl = 'https://open.er-api.com/v6/latest/VND';
  static const String _rateKey = 'vnd_to_php_rate';
  static const String _dateKey = 'last_fetch_date';

  Future<void> fetchAndSaveRate() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final double phpRate = (data['rates']['PHP'] as num).toDouble();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_rateKey, phpRate);
        await prefs.setString(_dateKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint('Network error: $e');
    }
  }

  Future<double?> getOfflineRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rateKey);
  }

  // FEATURE 3: Expose the date so the UI can show when it was last updated!
  Future<DateTime?> getLastFetchDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchString = prefs.getString(_dateKey);
    if (lastFetchString == null) return null;
    return DateTime.parse(lastFetchString);
  }

  Future<bool> isRateOutdated() async {
    final lastFetchDate = await getLastFetchDate();
    if (lastFetchDate == null) return true;
    final difference = DateTime.now().difference(lastFetchDate);
    return difference.inHours >= 24;
  }
}