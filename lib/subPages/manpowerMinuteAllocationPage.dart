import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/database/manpower_minute_allocation_database.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final uuid = Uuid();

class ManpowerMinuteAllocationPage extends StatefulWidget {
  final void Function(String block)? onBlockChanged;
  // final VoidCallback? onAllocationChanged;
  final void Function(int)? onAllocationChanged;

  const ManpowerMinuteAllocationPage({
    Key? key,
    this.onBlockChanged,
    this.onAllocationChanged,
  }) : super(key: key);

  @override
  _ManpowerMinuteAllocationPageState createState() =>
      _ManpowerMinuteAllocationPageState();
}

class _ManpowerMinuteAllocationPageState
    extends State<ManpowerMinuteAllocationPage>
    with AutomaticKeepAliveClientMixin {
  final Map<String, List<int>> blockLines = {
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

  DateTime selectedDate = DateTime.now();
  List<int> lineNumbers = [];
  List<Map<String, dynamic>> tableData = [];
  String? selectedBlock;
  bool isLoading = true;
  List<String> blockOptions = [];
  bool isMasterUser = false;
  Key tableKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _fetchUserWorkingArea();
    // _notifyAllocationChange();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _fetchUserWorkingArea() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('userID') ?? '';

      if (storedUserId.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      final client = Supabase.instance.client;
      final response =
          await client
              .from('USERS')
              .select('working_area')
              .eq('org_id', storedUserId)
              .maybeSingle();

      if (response == null || response['working_area'] == null) {
        _showNoWorkingAreaSnackbar();
        setState(() {
          blockOptions = [];
          isLoading = false;
        });
        return;
      }

      final rawArea = response['working_area'];
      List<dynamic> parsedArea =
          rawArea is String
              ? jsonDecode(rawArea)
              : (rawArea is List ? rawArea : []);

      List<String> areaList = parsedArea.map((e) => e.toString()).toList();

      setState(() {
        isMasterUser = areaList.contains('MASTER');
        blockOptions = isMasterUser ? blockLines.keys.toList() : areaList;
        if (blockOptions.isNotEmpty) {
          selectedBlock = blockOptions.first;
          selectBlock(selectedBlock!);
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching working area: $e');
      _showNoWorkingAreaSnackbar();
      setState(() {
        blockOptions = [];
        isLoading = false;
      });
    }
  }

  void _showNoWorkingAreaSnackbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No working area assigned. Please contact Admin.'),
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  Future<List<Map<String, dynamic>>> fetchByBlockAndDate(
    String block,
    String date,
  ) async {
    final db = await ManpowerMinuteAllocationDatabase.instance.database;
    return await db.query(
      'minute_allocation',
      where: 'block = ? AND date = ?',
      whereArgs: [block, date],
    );
  }

  void selectBlock(String blockName) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Step 1: Update block + reset table immediately to avoid ghost data
    setState(() {
      selectedBlock = blockName;
      lineNumbers = blockLines[blockName] ?? [];
      tableData = []; // Immediately clear the old table
    });

    widget.onBlockChanged?.call(blockName);

    // Step 2: Fetch fresh data from database
    final savedData = await fetchByBlockAndDate(blockName, dateStr);
    print('Loaded saved rows for $blockName on $dateStr: ${savedData.length}');

    // Step 3: Rebuild tableData with new values
    final newTable =
        lineNumbers.map((line) {
          final match = savedData.where((e) => e['lineNo'] == line).toList();

          if (match.isNotEmpty) {
            final existing = match.first;
            return {
              'id': existing['id'],
              'lineNo': line,
              'hrs8': existing['hrs8'],
              'hrs4to6': existing['hrs4to6'],
              'hrs6to8': existing['hrs6to8'],
              'hrs8to10': existing['hrs8to10'],
              'hrs10to12': existing['hrs10to12'],
            };
          } else {
            return {
              'id': uuid.v4(),
              'lineNo': line,
              'hrs8': null,
              'hrs4to6': null,
              'hrs6to8': null,
              'hrs8to10': null,
              'hrs10to12': null,
            };
          }
        }).toList();

    int total = 0;
    for (var row in newTable) {
      for (var key in ['hrs8', 'hrs4to6', 'hrs6to8', 'hrs8to10', 'hrs10to12']) {
        final value = row[key];
        if (value is int) {
          total += value;
        } else if (value is num) {
          total += value.toInt();
        }
      }
    }
    widget.onAllocationChanged?.call(total);

    // Step 4: Apply new data to the UI
    setState(() {
      tableData = newTable;
      tableKey = UniqueKey();
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
      // final id = uuid.v4();
      await ManpowerMinuteAllocationDatabase.instance.insertOrUpdate({
        'id': row['id'] ?? uuid.v4(),
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
    _notifyAllocationChange();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved Successfully')));
  }

  Widget buildTable() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frozen first column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFixedCell('Line No.'),
            ...tableData.map(
              (row) => _buildFixedCell(row['lineNo'].toString()),
            ),
          ],
        ),
        // Scrollable right side
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildHeaderCell('8 Hrs'),
                    _buildHeaderCell('4–6'),
                    _buildHeaderCell('6–8'),
                    _buildHeaderCell('8–10'),
                    _buildHeaderCell('10–12'),
                  ],
                ),
                ...tableData.map((row) {
                  return Row(
                    children: [
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
          ),
        ),
      ],
    );
  }

  Widget _buildFixedCell(String text) {
    return Container(
      width: 80,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHeaderCell(String title) {
    return Container(
      width: 100,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.blue[100],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _notifyAllocationChange() {
    int total = 0;

    for (var row in tableData) {
      for (var key in ['hrs8', 'hrs4to6', 'hrs6to8', 'hrs8to10', 'hrs10to12']) {
        final value = row[key];
        if (value is int) {
          total += value;
        } else if (value is num) {
          total += value.toInt(); // safe fallback
        }
      }
    }

    widget.onAllocationChanged?.call(total);
  }

  Widget _buildEditableCell(Map<String, dynamic> row, String key) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(4),
      child: TextFormField(
        initialValue: row[key]?.toString() ?? '',
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: (val) {
          row[key] = val.isEmpty ? null : int.tryParse(val);
          _notifyAllocationChange();
        },
        decoration: const InputDecoration(
          border: UnderlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(
      context,
    ); // 👈 required when using AutomaticKeepAliveClientMixin
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  DropdownButton<String>(
                    value: selectedBlock,
                    hint: Text('Select Block'),
                    items:
                        blockOptions.map((blockName) {
                          return DropdownMenuItem<String>(
                            value: blockName,
                            child: Text(blockName),
                          );
                        }).toList(),
                    onChanged: (value) => selectBlock(value!),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.date_range),
                    label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  key: tableKey,
                  child: buildTable(),
                ),
              ),
              ElevatedButton(onPressed: saveData, child: const Text('Save')),
            ],
          ),
        );
  }
}

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:square_dms_trial/database/manpower_minute_allocation_database.dart';
// import 'package:uuid/uuid.dart';

// final uuid = Uuid();

// class ManpowerMinuteAllocationPage extends StatefulWidget {
//   final String? selectedBlock;
//   final DateTime selectedDate;
//   final Map<String, List<int>> blockLines;
//   final void Function(int)? onAllocationChanged;

//   const ManpowerMinuteAllocationPage({
//     Key? key,
//     required this.selectedBlock,
//     required this.selectedDate,
//     required this.blockLines,
//     this.onAllocationChanged,
//   }) : super(key: key);

//   @override
//   _ManpowerMinuteAllocationPageState createState() =>
//       _ManpowerMinuteAllocationPageState();
// }

// class _ManpowerMinuteAllocationPageState
//     extends State<ManpowerMinuteAllocationPage> {
//   List<int> lineNumbers = [];
//   List<Map<String, dynamic>> tableData = [];
//   Key tableKey = UniqueKey();

//   @override
//   void initState() {
//     super.initState();
//     if (widget.selectedBlock != null && widget.selectedBlock!.isNotEmpty) {
//       selectBlock(widget.selectedBlock!);
//     }
//   }

//   @override
//   bool get wantKeepAlive => true;

//   @override
//   void didUpdateWidget(covariant ManpowerMinuteAllocationPage oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.selectedBlock != widget.selectedBlock ||
//         oldWidget.selectedDate != widget.selectedDate) {
//       if (widget.selectedBlock != null && widget.selectedBlock!.isNotEmpty) {
//         selectBlock(widget.selectedBlock!);
//       }
//     }
//   }

//   void selectBlock(String block) async {
//     final lines = widget.blockLines[block] ?? [];
//     final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

//     final savedData = await ManpowerMinuteAllocationDatabase.instance
//         .fetchByBlockAndDate(block, dateStr);

//     // Step 3: Rebuild tableData with new values
//     final newTable =
//         lines.map((line) {
//           final match = savedData.where((e) => e['lineNo'] == line).toList();

//           if (match.isNotEmpty) {
//             final existing = match.first;
//             return {
//               'id': existing['id'],
//               'lineNo': line,
//               'hrs8': existing['hrs8'],
//               'hrs4to6': existing['hrs4to6'],
//               'hrs6to8': existing['hrs6to8'],
//               'hrs8to10': existing['hrs8to10'],
//               'hrs10to12': existing['hrs10to12'],
//             };
//           } else {
//             return {
//               'id': uuid.v4(),
//               'lineNo': line,
//               'hrs8': null,
//               'hrs4to6': null,
//               'hrs6to8': null,
//               'hrs8to10': null,
//               'hrs10to12': null,
//             };
//           }
//         }).toList();

//     int total = 0;
//     for (var row in newTable) {
//       for (var key in ['hrs8', 'hrs4to6', 'hrs6to8', 'hrs8to10', 'hrs10to12']) {
//         final value = row[key];
//         if (value is int) {
//           total += value;
//         } else if (value is num) {
//           total += value.toInt();
//         }
//       }
//       debugPrint(total.toString());
//     }
//     widget.onAllocationChanged?.call(total);

//     setState(() {
//       tableData = newTable;
//       tableKey = UniqueKey();
//     });
//   }

//   Future<void> saveData() async {
//     final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
//     for (var row in tableData) {
//       await ManpowerMinuteAllocationDatabase.instance.insertOrUpdate({
//         'id': row['id'],
//         'block': widget.selectedBlock,
//         'date': dateStr,
//         'lineNo': row['lineNo'],
//         'hrs8': row['hrs8'],
//         'hrs4to6': row['hrs4to6'],
//         'hrs6to8': row['hrs6to8'],
//         'hrs8to10': row['hrs8to10'],
//         'hrs10to12': row['hrs10to12'],
//       });
//     }
//     _notifyAllocationChange();
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text('Saved successfully')));
//   }

//   Widget _buildEditableCell(Map<String, dynamic> row, String key) {
//     return Container(
//       width: 100,
//       padding: const EdgeInsets.all(4),
//       child: TextFormField(
//         initialValue: row[key]?.toString() ?? '',
//         keyboardType: TextInputType.number,
//         textAlign: TextAlign.center,
//         onChanged: (val) {
//           row[key] = val.isEmpty ? null : int.tryParse(val);
//           _notifyAllocationChange();
//         },
//         decoration: const InputDecoration(
//           border: UnderlineInputBorder(),
//           isDense: true,
//           contentPadding: EdgeInsets.symmetric(vertical: 8),
//         ),
//       ),
//     );
//   }

//   Widget _buildFixedCell(String text) {
//     return Container(
//       width: 80,
//       height: 48,
//       alignment: Alignment.center,
//       decoration: BoxDecoration(
//         color: Colors.grey[300],
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
//     );
//   }

//   Widget _buildHeaderCell(String title) {
//     return Container(
//       width: 100,
//       height: 48,
//       alignment: Alignment.center,
//       decoration: BoxDecoration(
//         color: Colors.blue[100],
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
//     );
//   }

//   void _notifyAllocationChange() {
//     int total = 0;

//     for (var row in tableData) {
//       for (var key in ['hrs8', 'hrs4to6', 'hrs6to8', 'hrs8to10', 'hrs10to12']) {
//         final value = row[key];

//         if (value is int) {
//           total += value;
//         } else if (value is String) {
//           total += int.tryParse(value) ?? 0;
//         } else if (value is num) {
//           total += value.toInt();
//         }
//       }
//     }
//     debugPrint('Minute Allocation Updated: $total');
//     widget.onAllocationChanged?.call(total);
//   }

//   Widget buildTable() {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Column(
//           children: [
//             _buildFixedCell('Line No.'),
//             ...tableData.map(
//               (row) => _buildFixedCell(row['lineNo'].toString()),
//             ),
//           ],
//         ),
//         Expanded(
//           child: SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     _buildHeaderCell('8 Hrs'),
//                     _buildHeaderCell('4–6'),
//                     _buildHeaderCell('6–8'),
//                     _buildHeaderCell('8–10'),
//                     _buildHeaderCell('10–12'),
//                   ],
//                 ),
//                 ...tableData.map((row) {
//                   return Row(
//                     children: [
//                       _buildEditableCell(row, 'hrs8'),
//                       _buildEditableCell(row, 'hrs4to6'),
//                       _buildEditableCell(row, 'hrs6to8'),
//                       _buildEditableCell(row, 'hrs8to10'),
//                       _buildEditableCell(row, 'hrs10to12'),
//                     ],
//                   );
//                 }).toList(),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (widget.selectedBlock == null) {
//       return Center(child: Text('No block selected'));
//     }

//     return Padding(
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         children: [
//           Text(
//             'Block: ${widget.selectedBlock} | Date: ${DateFormat('yyyy-MM-dd').format(widget.selectedDate)}',
//             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 12),
//           Expanded(child: SingleChildScrollView(child: buildTable())),
//           ElevatedButton(onPressed: saveData, child: Text('Save')),
//         ],
//       ),
//     );
//   }
// }
