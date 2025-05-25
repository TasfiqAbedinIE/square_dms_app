class SamEarnerRecord {
  final String id;
  final String block;
  final String date;
  final int lineNo;
  final int hrs8;
  final int hrs4to6;
  final int hrs6to8;
  final int hrs8to10;
  final int hrs10to12;

  SamEarnerRecord({
    required this.id,
    required this.block,
    required this.date,
    required this.lineNo,
    required this.hrs8,
    required this.hrs4to6,
    required this.hrs6to8,
    required this.hrs8to10,
    required this.hrs10to12,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'block': block,
      'date': date,
      'lineNo': lineNo,
      'hrs8': hrs8,
      'hrs4to6': hrs4to6,
      'hrs6to8': hrs6to8,
      'hrs8to10': hrs8to10,
      'hrs10to12': hrs10to12,
    };
  }
}
