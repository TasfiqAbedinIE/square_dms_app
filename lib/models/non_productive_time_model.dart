class NonProductiveEntry {
  final String id;
  final int lineNo;
  final String date;
  final String startTime;
  final String endTime;
  final int machine_num;
  final String reason;
  final int durationMinutes;
  final int totalNP;
  final double totalLostPcs;
  final String machine_code;
  final String deptid;
  final String res_dept;
  final String salesOrder;
  final String buyer;
  final String style;

  NonProductiveEntry({
    required this.id,
    required this.lineNo,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.machine_num,
    required this.reason,
    required this.durationMinutes,
    required this.totalNP,
    required this.totalLostPcs,
    required this.machine_code,
    required this.deptid,
    required this.res_dept,
    required this.salesOrder,
    required this.buyer,
    required this.style,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lineNo': lineNo,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'machine_num': machine_num,
      'reason': reason,
      'durationMinutes': durationMinutes,
      'totalNP': totalNP,
      'totalLostPcs': totalLostPcs,
      'machine_code': machine_code,
      'deptid': deptid,
      'res_dept': res_dept,
      'salesOrder': salesOrder,
      'buyer': buyer,
      'style': style,
    };
  }

  factory NonProductiveEntry.fromMap(Map<String, dynamic> map) {
    return NonProductiveEntry(
      id: map['id'],
      lineNo: map['lineNo'],
      date: map['date'],
      startTime: map['startTime'],
      endTime: map['endTime'],
      machine_num: map['machine_num'],
      reason: map['reason'],
      durationMinutes: map['durationMinutes'],
      totalNP: map['totalNP'],
      totalLostPcs: map['totalLostPcs'],
      machine_code: map['machine_code'],
      deptid: map['deptid'] ?? '',
      res_dept: map['res_dept'] ?? '',
      salesOrder: map['salesOrder'] ?? '',
      buyer: map['buyer'] ?? '',
      style: map['style'] ?? '',
    );
  }
}
