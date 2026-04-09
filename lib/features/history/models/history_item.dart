import 'dart:convert';

class HistoryItem {
  final double vndAmount;
  final double phpAmount;
  final DateTime timestamp;

  HistoryItem({
    required this.vndAmount,
    required this.phpAmount,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'vndAmount': vndAmount,
      'phpAmount': phpAmount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      vndAmount: map['vndAmount']?.toDouble() ?? 0.0,
      phpAmount: map['phpAmount']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  String toJson() => json.encode(toMap());
  factory HistoryItem.fromJson(String source) => HistoryItem.fromMap(json.decode(source));
}