import 'package:flutter/foundation.dart';

/// A single “line card” for Non-Productive Time:
///  • id: UUID string
///  • lineNo: integer line number
///  • date: yyyy-MM-dd string
///  • buyer, soNumber, style: strings
@immutable
class NonProductiveTimeLineCard {
  final String id;
  final int lineNo;
  final String date;
  final String buyer;
  final String soNumber;
  final String style;

  const NonProductiveTimeLineCard({
    required this.id,
    required this.lineNo,
    required this.date,
    required this.buyer,
    required this.soNumber,
    required this.style,
  });

  /// Construct from a SQLite row (Map<String, Object?>)
  factory NonProductiveTimeLineCard.fromMap(Map<String, Object?> map) {
    return NonProductiveTimeLineCard(
      id: map['id'] as String,
      lineNo: map['lineNo'] as int,
      date: map['date'] as String,
      buyer: map['buyer'] as String,
      soNumber: map['soNumber'] as String,
      style: map['style'] as String,
    );
  }

  /// Convert to a Map<String, Object?> suitable for SQLite insert/update
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'lineNo': lineNo,
      'date': date,
      'buyer': buyer,
      'soNumber': soNumber,
      'style': style,
    };
  }
}
