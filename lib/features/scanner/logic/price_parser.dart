class PriceParser {
  /// Parses text from ML Kit and aggressively hunts for Vietnamese price formats.
  static double? extractPrice(String text) {
    if (text.isEmpty) return null;

    // EDGE CASE 1: Fix common ML Kit OCR Typos (Letters O and o read as Zero)
    String cleanedText = text.replaceAll('O', '0').replaceAll('o', '0');

    List<double> foundPrices = [];

    // 1. The 'K' Format (50k, 150K, 50 k/bát, ₫50k, 50-100k)
    // (?:\D|^) ensures it catches numbers even if they touch symbols (like -, ~, :, or ₫)
    final kRegex = RegExp(r'(?:\D|^)(\d{1,3})\s?[kK](?:\W|$)');
    for (final match in kRegex.allMatches(cleanedText)) {
      final parsed = double.tryParse(match.group(1)!);
      if (parsed != null) foundPrices.add(parsed * 1000);
    }

    // 2. The Standard Format (150,000, 150.000, 150,000đ)
    final standardRegex = RegExp(r'(?:\D|^)(\d{1,3}(?:[.,]\d{3})+)(?:\W|$)');
    for (final match in standardRegex.allMatches(cleanedText)) {
      String cleanNumber = match.group(1)!.replaceAll(',', '').replaceAll('.', '');
      final parsed = double.tryParse(cleanNumber);
      if (parsed != null) foundPrices.add(parsed);
    }

    // 3. Raw Thousands (50000, 100000)
    // Must start with 1-9 to naturally ignore phone numbers (which start with 0)
    final rawRegex = RegExp(r'(?:\D|^)([1-9]\d{3,6})(?:\W|$)');
    for (final match in rawRegex.allMatches(cleanedText)) {
      final parsed = double.tryParse(match.group(1)!);
      if (parsed != null) foundPrices.add(parsed);
    }

    // EDGE CASE 4: Filter out accidental years or tiny numbers
    // (e.g., "Since 1998" -> 1,998 VND is only 4 PHP)
    foundPrices.removeWhere((price) => price < 2000);

    if (foundPrices.isEmpty) return null;

    // EDGE CASE 2 & 3: Handle Ranges (e.g., "50k - 100k")
    // If the scanner picks up multiple valid prices inside your target box,
    // it sorts them and returns the HIGHEST price.
    // Rule of travel: It is always safer to budget for the maximum possible price!
    foundPrices.sort();
    return foundPrices.last;
  }
}