class SewingProcess {
  final String processName;
  final String item;
  final String machine;
  final String form;
  final double smv;

  SewingProcess({
    required this.processName,
    required this.item,
    required this.machine,
    required this.form,
    required this.smv,
  });

  Map<String, dynamic> toMap() {
    return {
      'process_name': processName,
      'item': item,
      'machine': machine,
      'form': form,
      'smv': smv,
    };
  }

  factory SewingProcess.fromJson(Map<String, dynamic> json) {
    return SewingProcess(
      processName: json['process_name'],
      item: json['item'],
      machine: json['machine'],
      form: json['form'],
      smv: (json['smv'] as num).toDouble(),
    );
  }

  factory SewingProcess.fromMap(Map<String, dynamic> map) {
    return SewingProcess(
      processName: map['process_name'],
      item: map['item'],
      machine: map['machine'],
      form: map['form'],
      smv: (map['smv'] as num).toDouble(),
    );
  }
}
