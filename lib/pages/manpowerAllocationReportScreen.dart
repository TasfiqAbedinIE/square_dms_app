import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManpowerAllocationReportPage extends StatefulWidget {
  const ManpowerAllocationReportPage({super.key});

  @override
  State<ManpowerAllocationReportPage> createState() =>
      _ManpowerAllocationReportPageState();
}

class _ManpowerAllocationReportPageState
    extends State<ManpowerAllocationReportPage> {
  DateTime selectedDate = DateTime.now();
  String selectedBlock = '1-6';
  final List<String> blocks = [
    '1-6',
    '7-15',
    '16-21',
    '22-30',
    '31-36',
    '37-45',
    '46-49',
    '50-55',
    '56-62',
    '63-69',
    '70-76',
    '77-81',
    '82-86',
    '87-91',
    '92-96',
    '97-105',
    '106-114',
    '115-124',
  ];

  bool loading = true;
  List<Map<String, dynamic>> samEarner = [];
  List<Map<String, dynamic>> minute = [];
  List<Map<String, dynamic>> other = [];

  Future<void> _fetchData() async {
    setState(() => loading = true);
    final supabase = Supabase.instance.client;
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    final response = await supabase
        .from('sewing_manpower_allocation')
        .select()
        .eq('block', selectedBlock)
        .eq('date', dateStr);

    samEarner =
        response
            .where((row) => row['allocation_type'] == 'SAM_EARNER')
            .toList();
    minute =
        response.where((row) => row['allocation_type'] == 'MINUTE').toList();
    other = response.where((row) => row['allocation_type'] == 'OTHER').toList();

    setState(() => loading = false);
  }

  int _sumSamEarner() {
    return samEarner.fold(
      0,
      (sum, row) =>
          sum +
          (int.tryParse(row['hrs8']?.toString() ?? '0') ?? 0) +
          (int.tryParse(row['hrs4to6']?.toString() ?? '0') ?? 0) +
          (int.tryParse(row['hrs6to8']?.toString() ?? '0') ?? 0) +
          (int.tryParse(row['hrs8to10']?.toString() ?? '0') ?? 0) +
          (int.tryParse(row['hrs10to12']?.toString() ?? '0') ?? 0),
    );
  }

  int _sumMinute() {
    return minute.fold(
      0,
      (sum, row) =>
          sum +
          (int.tryParse(row['hrs8']?.toString() ?? '0') ?? 0) +
          (int.tryParse(row['hrs4to6']?.toString() ?? '0') ?? 0) +
          (int.tryParse(row['hrs6to8']?.toString() ?? '0') ?? 0) +
          (int.tryParse(row['hrs8to10']?.toString() ?? '0') ?? 0) +
          (int.tryParse(row['hrs10to12']?.toString() ?? '0') ?? 0),
    );
  }

  int _sumOther() {
    return other.fold(
      0,
      (sum, row) => sum + (int.tryParse(row['count']?.toString() ?? '0') ?? 0),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    final total = _sumSamEarner() + _sumMinute() + _sumOther();

    return Scaffold(
      // appBar: AppBar(title: const Text('Manpower Allocation Report')),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                // Block dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedBlock,
                    items:
                        blocks
                            .map(
                              (block) => DropdownMenuItem(
                                value: block,
                                child: Text(block),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedBlock = val);
                        _fetchData();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Block',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Date selector
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2026),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                      _fetchData();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard('SAM_EARNER', samEarner, _sumSamEarner()),
            _buildSectionCard('MINUTE', minute, _sumMinute()),
            _buildOtherSectionCard(),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Total Allocated for Block $selectedBlock: $total',
                // style: theme.textTheme.titleMedium?.copyWith(
                //   fontWeight: FontWeight.bold,
                // ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    List<Map<String, dynamic>> data,
    int total,
  ) {
    return Card(
      // margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      // elevation: 2,
      child: ExpansionTile(
        title: Text(
          '$title (Total: $total)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Line')),
                DataColumn(label: Text('8H')),
                DataColumn(label: Text('4–6')),
                DataColumn(label: Text('6–8')),
                DataColumn(label: Text('8–10')),
                DataColumn(label: Text('10–12')),
              ],
              rows:
                  data.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row['line_no'].toString())),
                        DataCell(Text((row['hrs8'] ?? 0).toString())),
                        DataCell(Text((row['hrs4to6'] ?? 0).toString())),
                        DataCell(Text((row['hrs6to8'] ?? 0).toString())),
                        DataCell(Text((row['hrs8to10'] ?? 0).toString())),
                        DataCell(Text((row['hrs10to12'] ?? 0).toString())),
                      ],
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOtherSectionCard() {
    final total = _sumOther();

    return Card(
      // margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      // elevation: 2,
      child: ExpansionTile(
        title: Text(
          'OTHERS (Total: $total)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Factor')),
                DataColumn(label: Text('Count')),
                DataColumn(label: Text('Transfer To')),
              ],
              rows:
                  other.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row['factor'] ?? '')),
                        DataCell(Text((row['count'] ?? 0).toString())),
                        DataCell(
                          row['factor'] == 'TRANSFER TO OTHER BLOCK'
                              ? Text('→ ${row['transfer_to'] ?? ''}')
                              : const Text('-'),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
