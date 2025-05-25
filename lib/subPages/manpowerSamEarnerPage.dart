import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/database/manpower_samEarner_database.dart';
import 'package:uuid/uuid.dart';

final uuid = Uuid();

class SamEarnerPage extends StatefulWidget {
  @override
  _SamEarnerPageState createState() => _SamEarnerPageState();
}

class _SamEarnerPageState extends State<SamEarnerPage> {
  final List<Map<String, dynamic>> blocks = [
    {
      'name': '1-6',
      'lines': [1, 2, 3, 4, 5, 6],
    },
    {
      'name': '7-15',
      'lines': [7, 8, 9, 10, 11, 12, 13, 14, 15],
    },
  ];

  String? selectedBlock;
  DateTime selectedDate = DateTime.now();
  List<int> lineNumbers = [];
  List<Map<String, dynamic>> tableData = [];

  void selectBlock(String blockName) {
    final block = blocks.firstWhere((b) => b['name'] == blockName);
    setState(() {
      selectedBlock = blockName;
      lineNumbers = List<int>.from(block['lines']);
      tableData =
          lineNumbers
              .map(
                (line) => {
                  'lineNo': line,
                  'hrs8': null,
                  'hrs4to6': null,
                  'hrs6to8': null,
                  'hrs8to10': null,
                  'hrs10to12': null,
                },
              )
              .toList();
    });
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> saveData() async {
    for (var row in tableData) {
      final id = uuid.v4();
      await SamEarnerDatabase.instance.insertOrUpdate({
        'id': id,
        'block': selectedBlock!,
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'lineNo': row['lineNo'],
        'hrs8': row['hrs8'],
        'hrs4to6': row['hrs4to6'],
        'hrs6to8': row['hrs6to8'],
        'hrs8to10': row['hrs8to10'],
        'hrs10to12': row['hrs10to12'],
      });
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved Successfully')));
  }

  Widget buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          // Header Row
          Row(
            children: [
              _buildFixedCell('Line No.'),
              _buildHeaderCell('8 Hrs'),
              _buildHeaderCell('4–6'),
              _buildHeaderCell('6–8'),
              _buildHeaderCell('8–10'),
              _buildHeaderCell('10–12'),
            ],
          ),
          // Data Rows
          ...tableData.map((row) {
            return Row(
              children: [
                _buildFixedCell(row['lineNo'].toString()),
                _buildEditableCell(row, 'hrs8'),
                _buildEditableCell(row, 'hrs4to6'),
                _buildEditableCell(row, 'hrs6to8'),
                _buildEditableCell(row, 'hrs8to10'),
                _buildEditableCell(row, 'hrs10to12'),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFixedCell(String text) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        // border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHeaderCell(String title) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        border: Border.all(color: Colors.black12),
      ),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEditableCell(Map<String, dynamic> row, String key) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(4),
      child: TextFormField(
        initialValue: row[key] == null ? '' : row[key].toString(),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center, // 👉 Center text
        onChanged: (val) {
          row[key] = val.isEmpty ? null : int.tryParse(val);
        },
        decoration: const InputDecoration(
          border: UnderlineInputBorder(), // 👉 Only bottom border
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            vertical: 8,
          ), // Tight vertical padding
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  value: selectedBlock,
                  hint: Text('Select Block'),
                  items:
                      blocks.map((block) {
                        return DropdownMenuItem<String>(
                          value: block['name'],
                          child: Text(block['name']),
                        );
                      }).toList(),
                  onChanged: (value) => selectBlock(value!),
                ),
                SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: pickDate,
                  icon: Icon(Icons.date_range),
                  label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                ),
              ],
            ),
            SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: buildTable())),
            ElevatedButton(onPressed: saveData, child: Text('Save')),
          ],
        ),
      ),
    );
  }
}
