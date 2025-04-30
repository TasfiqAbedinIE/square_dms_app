class SkillMatrixRecord {
  final int id;
  final String referenceNumber;
  final int lineNumber;
  final String buyer;
  final String salesDocument;
  final String style;
  final String item;
  final int layoutTarget;
  final String date;
  final String operatorID;
  final String processName;
  final String machine;
  final String form;
  final int lapCount;
  final double avgCycle;
  final int capacityPH;
  final String deptid;

  SkillMatrixRecord({
    required this.id,
    required this.referenceNumber,
    required this.lineNumber,
    required this.buyer,
    required this.salesDocument,
    required this.style,
    required this.item,
    required this.layoutTarget,
    required this.date,
    required this.operatorID,
    required this.processName,
    required this.machine,
    required this.form,
    required this.lapCount,
    required this.avgCycle,
    required this.capacityPH,
    required this.deptid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'referenceNumber': referenceNumber,
      'lineNumber': lineNumber,
      'buyer': buyer,
      'salesDocument': salesDocument,
      'style': style,
      'item': item,
      'layoutTarget': layoutTarget,
      'date': date,
      'operatorID': operatorID,
      'processName': processName,
      'machine': machine,
      'form': form,
      'lapCount': lapCount,
      'avgCycle': avgCycle,
      'capacityPH': capacityPH,
      'deptid': deptid,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referenceNumber': referenceNumber,
      'lineNumber': lineNumber,
      'buyer': buyer,
      'salesDocument': salesDocument,
      'style': style,
      'item': item,
      'layoutTarget': layoutTarget,
      'date': date,
      'operatorID': operatorID,
      'processName': processName,
      'machine': machine,
      'form': form,
      'lapCount': lapCount,
      'avgCycle': avgCycle,
      'capacityPH': capacityPH,
      'deptid': deptid,
    };
  }

  factory SkillMatrixRecord.fromMap(Map<String, dynamic> map) {
    return SkillMatrixRecord(
      id: map['id'],
      referenceNumber: map['referenceNumber'] ?? '',
      lineNumber: map['lineNumber'] ?? 0,
      buyer: map['buyer'] ?? '',
      salesDocument: map['salesDocument'] ?? '',
      style: map['style'] ?? '',
      item: map['item'] ?? '',
      layoutTarget: map['layoutTarget'] ?? 0,
      date: map['date'] ?? '',
      operatorID: map['operatorID'] ?? '',
      processName: map['processName'] ?? '',
      machine: map['machine'] ?? '',
      form: map['form'] ?? '',
      lapCount: map['lapCount'] ?? 0,
      avgCycle: (map['avgCycle'] ?? 0).toDouble(),
      capacityPH: map['capacityPH'] ?? 0,
      deptid: map['deptid'] ?? '',
    );
  }
}
