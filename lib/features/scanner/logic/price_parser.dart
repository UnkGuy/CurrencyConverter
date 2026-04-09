class PriceParser {
  /// Parses text from ML Kit and tries to find a valid VND price.
  /// Returns the raw VND amount (e.g., 150000.0) or null if none is found.
  static double? extractPrice(String text) {
    if (text.isEmpty) return null;

    // 1. Look for standard numbers (150,000 or 150.000)
    final standardRegex = RegExp(r'\b\d{1,3}(?:[.,]\d{3})+\b');
    // 2. Look for the "k" abbreviation (15k, 150K, 50 k)
    final kRegex = RegExp(r'\b(\d{1,3})\s?[kK]\b');

    final standardMatch = standardRegex.firstMatch(text);
    final kMatch = kRegex.firstMatch(text);

    if (standardMatch != null) {
      String cleanNumber = standardMatch.group(0)!.replaceAll(',', '').replaceAll('.', '');
      return double.tryParse(cleanNumber);
    } else if (kMatch != null) {
      String cleanNumber = kMatch.group(1)!;
      final parsed = double.tryParse(cleanNumber);
      return parsed != null ? parsed * 1000 : null;
    }

    return null;
  }
}