import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SkillMatrixReportPage extends StatefulWidget {
  const SkillMatrixReportPage({super.key});

  @override
  State<SkillMatrixReportPage> createState() => _SkillMatrixReportPageState();
}

class _SkillMatrixReportPageState extends State<SkillMatrixReportPage> {
  String selectedSearchBy = 'Process Name';
  String? selectedProcess;
  String? operatorId;
  int? selectedLine;
  bool isTableView = false;

  List<String> processList = [];
  List<Map<String, dynamic>> searchResults = [];

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    loadProcessNames();
  }

  Future<void> loadProcessNames() async {
    final response = await supabase
        .from('skillMatrixRecords')
        .select('processName')
        // .is_('processName', false)
        .order('processName', ascending: true);

    final rawList = List<Map<String, dynamic>>.from(response);
    final names =
        rawList.map((e) => e['processName'].toString()).toSet().toList();
    setState(() => processList = names);
  }

  Future<void> performSearch() async {
    List<Map<String, dynamic>> results = [];

    if (selectedSearchBy == 'Process Name' && selectedProcess != null) {
      results = await fetchFromSupabaseByProcess(selectedProcess!);
    } else if (selectedSearchBy == 'Operator ID' &&
        operatorId != null &&
        operatorId!.isNotEmpty) {
      results = await fetchFromSupabaseByOperator(operatorId!);
    } else if (selectedSearchBy == 'Line Number' && selectedLine != null) {
      results = await fetchFromSupabaseByLine(selectedLine!);
    }

    setState(() => searchResults = results);
  }

  Future<List<Map<String, dynamic>>> fetchFromSupabaseByProcess(
    String process,
  ) async {
    final response = await supabase
        .from('skillMatrixRecords')
        .select()
        .eq('processName', process);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchFromSupabaseByOperator(
    String operatorId,
  ) async {
    final response = await supabase
        .from('skillMatrixRecords')
        .select()
        .eq('operatorID', operatorId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchFromSupabaseByLine(
    int lineNumber,
  ) async {
    final response = await supabase
        .from('skillMatrixRecords')
        .select()
        .eq('lineNumber', lineNumber);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 72, 191, 227),
        foregroundColor: Colors.white,
        title: const Text("Skill Matrix Report"),
        actions: [
          IconButton(
            icon: Icon(isTableView ? Icons.view_agenda : Icons.table_chart),
            tooltip: isTableView ? "Card View" : "Table View",
            onPressed: () => setState(() => isTableView = !isTableView),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            initialValue: selectedSearchBy,
            onSelected: (value) {
              setState(() => selectedSearchBy = value);
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: 'Process Name',
                    child: Text('By Process Name'),
                  ),
                  PopupMenuItem(
                    value: 'Operator ID',
                    child: Text('By Operator ID'),
                  ),
                  PopupMenuItem(
                    value: 'Line Number',
                    child: Text('By Line Number'),
                  ),
                ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input Fields
            if (selectedSearchBy == "Process Name")
              DropdownSearch<String>(
                items: (filter, _) => processList,
                popupProps: const PopupProps.menu(showSearchBox: true),
                onChanged: (val) => selectedProcess = val,
                decoratorProps: const DropDownDecoratorProps(
                  decoration: InputDecoration(labelText: "Select Process Name"),
                ),
              ),
            if (selectedSearchBy == "Operator ID")
              TextField(
                decoration: const InputDecoration(
                  labelText: "Enter Operator ID",
                ),
                onChanged: (val) => operatorId = val,
              ),
            if (selectedSearchBy == "Line Number")
              DropdownButtonFormField<int>(
                value: selectedLine,
                items:
                    List.generate(124, (index) => index + 1)
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text("Line $e"),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => selectedLine = val),
                decoration: const InputDecoration(
                  labelText: "Select Line Number",
                ),
              ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: performSearch,
              icon: const Icon(Icons.search),
              label: const Text("Search"),
            ),

            const SizedBox(height: 16),

            Expanded(
              child:
                  searchResults.isEmpty
                      ? const Center(child: Text("No data to display"))
                      : isTableView
                      ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("Operator ID")),
                              DataColumn(label: Text("Process")),
                              DataColumn(label: Text("Line")),
                              DataColumn(label: Text("Avg Cycle")),
                              DataColumn(label: Text("Cap/hr")),
                            ],
                            rows:
                                searchResults.map((record) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          record['operatorID']?.toString() ??
                                              '',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          record['processName']?.toString() ??
                                              '',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          record['lineNumber']?.toString() ??
                                              '',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          record['avgCycle']?.toString() ?? '',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          record['capacityPH']?.toString() ??
                                              '',
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final record = searchResults[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Operator ID: ${record['operatorID']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Process Name: ${record['processName']}",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Avg Cycle Time: ${record['avgCycle']} sec | Capacity/hr: ${record['capacityPH']}",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
