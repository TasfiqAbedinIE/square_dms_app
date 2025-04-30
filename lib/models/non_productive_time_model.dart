class NonProductiveEntry {
  final int id;
  final int lineNo;
  final String date;
  final String startTime;
  final String endTime;
  final int machine_num;
  final String reason;

  NonProductiveEntry({
    required this.id,
    required this.lineNo,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.machine_num,
    required this.reason,
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
    );
  }
}
