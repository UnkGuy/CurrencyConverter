import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  // We'll use the open, free endpoint of ExchangeRate-API for easy testing.
  // It gives us rates based on 1 VND.
  static const String _apiUrl = 'https://open.er-api.com/v6/latest/VND';

  // Keys for saving data locally via SharedPreferences
  static const String _rateKey = 'vnd_to_php_rate';
  static const String _dateKey = 'last_fetch_date';

  /// 1. Updates the exchange rate from the internet and saves it locally.
  Future<void> fetchAndSaveRate() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract the PHP conversion rate from the JSON response
        final double phpRate = (data['rates']['PHP'] as num).toDouble();

        // Initialize SharedPreferences to save the data offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_rateKey, phpRate);
        await prefs.setString(_dateKey, DateTime.now().toIso8601String());

        debugPrint('Success! Saved new rate: 1 VND = $phpRate PHP');
      } else {
        debugPrint('API Error: Server responded with status ${response.statusCode}');
      }
    } catch (e) {
      // If the user has no internet, the http.get will throw an error.
      // We catch it here so the app doesn't crash.
      debugPrint('Network error. Will rely on the offline cached rate. Error: $e');
    }
  }

  /// 2. Retrieves the saved rate for your scanner screen to use instantly.
  Future<double?> getOfflineRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rateKey);
  }

  /// 3. Checks if the saved rate is older than 24 hours.
  Future<bool> isRateOutdated() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchString = prefs.getString(_dateKey);

    // If there's no saved date, we definitely need to fetch the rate!
    if (lastFetchString == null) return true;

    final lastFetchDate = DateTime.parse(lastFetchString);
    final difference = DateTime.now().difference(lastFetchDate);

    // Returns true if the saved rate is more than 24 hours old
    return difference.inHours >= 24;
  }
}