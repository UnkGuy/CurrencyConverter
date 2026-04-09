class PriceParser {
  /// Parses text from ML Kit and aggressively hunts for Vietnamese price formats.
  static double? extractPrice(String text) {
    if (text.isEmpty) return null;

    // Fix common ML Kit OCR Typos (Letters O and o mistakenly read as Zero)
    String cleanedText = text.replaceAll('O', '0').replaceAll('o', '0').toLowerCase();
    List<double> foundPrices = [];

    // 1. The 'K' Format (50k, 150K, 50 k/bát)
    // Matches 1-3 digits, optional space, 'k', and a word boundary (like a slash or space)
    final kRegex = RegExp(r'(\d{1,3})\s*k\b');
    for (final match in kRegex.allMatches(cleanedText)) {
      final parsed = double.tryParse(match.group(1)!);
      if (parsed != null) foundPrices.add(parsed * 1000);
    }

    // 2. The Standard Format (12.000, 15,000, 46 000)
    // Matches 1-3 digits, a dot/comma/space separator, and exactly 3 digits
    final standardRegex = RegExp(r'(\d{1,3})[.,\s](\d{3})\b');
    for (final match in standardRegex.allMatches(cleanedText)) {
      String cleanNumber = match.group(1)! + match.group(2)!;
      final parsed = double.tryParse(cleanNumber);
      if (parsed != null) foundPrices.add(parsed);
    }

    // 3. Raw Thousands (15000, 50000)
    final rawRegex = RegExp(r'\b([1-9]\d{3,6})\b');
    for (final match in rawRegex.allMatches(cleanedText)) {
      final parsed = double.tryParse(match.group(1)!);
      if (parsed != null) foundPrices.add(parsed);
    }

    // Filter out accidental years or tiny numbers (Nothing costs less than 2,000 VND)
    foundPrices.removeWhere((price) => price < 2000);

    if (foundPrices.isEmpty) return null;

    // Sort and take the maximum found in the localized block just to be safe
    foundPrices.sort();
    return foundPrices.last;
  }
}