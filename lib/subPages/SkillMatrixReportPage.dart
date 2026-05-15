import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SkillMatrixReportPage extends StatefulWidget {
  const SkillMatrixReportPage({super.key});

  @override
  State<SkillMatrixReportPage> createState() => _SkillMatrixReportPageState();
}

class _SkillMatrixReportPageState extends State<SkillMatrixReportPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  final Map<String, List<int>> blockLines = const {
    '1-6': [1, 2, 3, 4, 5, 6],
    '7-15': [7, 8, 9, 10, 11, 12, 13, 14, 15],
    '16-21': [16, 17, 18, 19, 20, 21],
    '22-30': [22, 23, 24, 25, 26, 27, 28, 29, 30],
    '31-36': [31, 32, 33, 34, 35, 36],
    '37-45': [37, 38, 39, 40, 41, 42, 43, 44, 45],
    '46-49': [46, 47, 48, 49],
    '50-55': [50, 51, 52, 53, 54, 55],
    '56-62': [56, 57, 58, 59, 60, 61, 62],
    '63-69': [63, 64, 65, 66, 67, 68, 69],
    '70-76': [70, 71, 72, 73, 74, 75, 76],
    '77-81': [77, 78, 79, 80, 81],
    '82-86': [82, 83, 84, 85, 86],
    '87-91': [87, 88, 89, 90, 91],
    '92-96': [92, 93, 94, 95, 96],
    '97-105': [97, 98, 99, 100, 101, 102, 103, 104, 105],
    '106-114': [106, 107, 108, 109, 110, 111, 112, 113, 114],
    '115-124': [115, 116, 117, 118, 119, 120, 121, 122, 123, 124],
  };

  String? selectedBlock;
  String? selectedMachine;
  bool isLoading = false;

  List<Map<String, dynamic>> blockRecords = [];

  List<Map<String, dynamic>> get filteredRecords {
    if (selectedMachine == null || selectedMachine == 'All') {
      return blockRecords;
    }

    return blockRecords
        .where((record) => _value(record['machine']) == selectedMachine)
        .toList();
  }

  List<String> get machineOptions {
    final machines =
        blockRecords
            .map((record) => _value(record['machine']))
            .where(
              (machine) =>
                  machine.isNotEmpty &&
                  !_OperatorSkillSummary.isIgnoredMachine(machine),
            )
            .toSet()
            .toList()
          ..sort();

    return ['All', ...machines];
  }

  List<_OperatorSkillSummary> get blockOperatorSummaries {
    return _buildOperatorSummaries(blockRecords);
  }

  List<_OperatorSkillSummary> get filteredOperatorSummaries {
    return _buildOperatorSummaries(filteredRecords);
  }

  List<_OperatorSkillSummary> _buildOperatorSummaries(
    List<Map<String, dynamic>> records,
  ) {
    final summariesByOperator = <String, _OperatorSkillSummary>{};

    for (final record in records) {
      final operatorId = _value(record['operatorID']);
      if (operatorId.isEmpty) continue;

      final summary = summariesByOperator.putIfAbsent(
        operatorId,
        () => _OperatorSkillSummary(operatorId: operatorId),
      );

      summary.addRecord(record);
    }

    final summaries = summariesByOperator.values.toList();
    summaries.sort((a, b) => a.operatorId.compareTo(b.operatorId));
    return summaries;
  }

  int get totalOperator => blockOperatorSummaries.length;

  int get multiSkillOperatorCount =>
      blockOperatorSummaries.where((summary) => summary.skillScore >= 2).length;

  int get totalSkillScore => blockOperatorSummaries.fold(
    0,
    (total, summary) => total + summary.skillScore,
  );

  double get skillIndex =>
      totalOperator == 0 ? 0 : totalSkillScore / totalOperator;

  Future<void> loadBlockRecords(String block) async {
    final lines = blockLines[block] ?? [];

    setState(() {
      selectedBlock = block;
      selectedMachine = 'All';
      isLoading = true;
      blockRecords = [];
    });

    try {
      final response = await supabase
          .from('skillMatrixRecords')
          .select(
            'id,referenceNumber,lineNumber,operatorID,processName,machine,processSequence',
          )
          .inFilter('lineNumber', lines)
          .order('lineNumber', ascending: true)
          .order('operatorID', ascending: true)
          .order('processSequence', ascending: true)
          .order('id', ascending: true);

      if (!mounted) return;
      setState(() {
        blockRecords = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load skill matrix records: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  static String _value(dynamic value) => value?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final summaries = filteredOperatorSummaries;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 72, 191, 227),
        foregroundColor: Colors.white,
        title: const Text("Skill Matrix Report"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedBlock,
              items:
                  blockLines.keys
                      .map(
                        (block) => DropdownMenuItem(
                          value: block,
                          child: Text("Block $block"),
                        ),
                      )
                      .toList(),
              onChanged: (block) {
                if (block != null) {
                  loadBlockRecords(block);
                }
              },
              decoration: const InputDecoration(
                labelText: "Production Block",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _DashboardCards(
              totalOperator: totalOperator,
              multiSkillOperatorCount: multiSkillOperatorCount,
              skillIndex: skillIndex,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue:
                  machineOptions.contains(selectedMachine)
                      ? selectedMachine
                      : 'All',
              items:
                  machineOptions
                      .map(
                        (machine) => DropdownMenuItem(
                          value: machine,
                          child: Text(
                            machine == 'All' ? 'All Machines' : machine,
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  blockRecords.isEmpty
                      ? null
                      : (machine) {
                        setState(() => selectedMachine = machine ?? 'All');
                      },
              decoration: const InputDecoration(
                labelText: "Machine Type",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : selectedBlock == null
                      ? const Center(
                        child: Text("Select a production block to view data"),
                      )
                      : summaries.isEmpty
                      ? const Center(child: Text("No operator data found"))
                      : _OperatorSkillTable(summaries: summaries),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCards extends StatelessWidget {
  final int totalOperator;
  final int multiSkillOperatorCount;
  final double skillIndex;

  const _DashboardCards({
    required this.totalOperator,
    required this.multiSkillOperatorCount,
    required this.skillIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DashboardCard(
            title: "Total Operator",
            value: totalOperator.toString(),
            icon: Icons.groups,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DashboardCard(
            title: "Multi Skill",
            value: multiSkillOperatorCount.toString(),
            icon: Icons.stars,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DashboardCard(
            title: "Skill Index",
            value: skillIndex.toStringAsFixed(2),
            icon: Icons.analytics,
          ),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color.fromARGB(255, 72, 191, 227)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorSkillTable extends StatelessWidget {
  final List<_OperatorSkillSummary> summaries;

  const _OperatorSkillTable({required this.summaries});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Operator ID")),
            DataColumn(label: Text("Unique Machine")),
            DataColumn(label: Text("Unique Process")),
            DataColumn(label: Text("Skill Score")),
            DataColumn(label: Text("Machines")),
            DataColumn(label: Text("Processes")),
          ],
          rows:
              summaries
                  .map(
                    (summary) => DataRow(
                      cells: [
                        DataCell(Text(summary.operatorId)),
                        DataCell(Text(summary.uniqueMachineCount.toString())),
                        DataCell(Text(summary.uniqueProcessCount.toString())),
                        DataCell(Text(summary.skillScore.toString())),
                        DataCell(Text(summary.machineNames)),
                        DataCell(Text(summary.processNames)),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _OperatorSkillSummary {
  final String operatorId;
  final Set<String> machines = {};
  final Set<String> processes = {};

  _OperatorSkillSummary({required this.operatorId});

  void addRecord(Map<String, dynamic> record) {
    final machine = _clean(record['machine']);
    final process = _clean(record['processName']);

    if (isIgnoredMachine(machine)) return;

    if (machine.isNotEmpty) machines.add(machine);
    if (process.isNotEmpty) processes.add(process);
  }

  int get uniqueMachineCount => machines.length;
  int get uniqueProcessCount => processes.length;
  int get skillScore => uniqueMachineCount * uniqueProcessCount;

  String get machineNames => _joined(machines);
  String get processNames => _joined(processes);

  static String _clean(dynamic value) => value?.toString().trim() ?? '';

  static bool isIgnoredMachine(String machine) {
    final normalizedMachine = machine.trim().toUpperCase();
    return normalizedMachine == 'HEL' || normalizedMachine == 'IRON';
  }

  static String _joined(Set<String> values) {
    final sortedValues = values.toList()..sort();
    return sortedValues.join(', ');
  }
}
