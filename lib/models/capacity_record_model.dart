class CapacityRecord {
  // final int? id;
  final String referenceNumber;
  final int lineNumber;
  final String salesDocument;
  final String buyer;
  final String style;
  final String item;
  final int layoutTarget;
  final String date;
  final String deptid;

  CapacityRecord({
    // this.id,
    required this.referenceNumber,
    required this.lineNumber,
    required this.salesDocument,
    required this.buyer,
    required this.style,
    required this.item,
    required this.layoutTarget,
    required this.date,
    required this.deptid,
  });

  Map<String, dynamic> toMap() {
    return {
      // 'id': id,
      'referenceNumber': referenceNumber,
      'lineNumber': lineNumber,
      'salesDocument': salesDocument,
      'buyer': buyer,
      'style': style,
      'item': item,
      'layoutTarget': layoutTarget,
      'date': date,
      'deptid': deptid,
    };
  }

  static CapacityRecord fromMap(Map<String, dynamic> map) {
    return CapacityRecord(
      // id: map['id'],
      referenceNumber: map['referenceNumber'],
      lineNumber: map['lineNumber'],
      salesDocument: map['salesDocument'],
      buyer: map['buyer'],
      style: map['style'],
      item: map['item'],
      layoutTarget: map['layoutTarget'],
      date: map['date'],
      deptid: map['deptid'],
    );
  }
}
