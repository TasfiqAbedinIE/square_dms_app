import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/database/manpower_other_allocation_database.dart';
import 'package:square_dms_trial/database/manpower_minute_allocation_database.dart';
import 'package:square_dms_trial/database/manpower_samEarner_database.dart';
import 'package:square_dms_trial/database/manpower_summary_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final uuid = Uuid();
String userID = '';

const List<String> manpowerFactors = [
  "SUPERVISOR",
  "INPUT GIRL",
  "REPORTER",
  "TECHNICIAN",
  "WEAK",
  "REWORK",
  "TEMPLATE",
  "IRON",
  "NEEDLE",
  "CUTTING",
  "HALFDONE",
  "CASUAL LEAVE",
  "LOADER",
  "SKFL",
  "ADMIN",
  "FINISHING",
  "PILOT",
  "WATER THROUGH",
  "RESIGN",
  "TRAINING",
  "SKILL DEV",
  "T & D",
  "WASHING",
  "EMBROIDERY",
  "PRINTING",
  "CAP",
];

class ManpowerOtherAllocationPage extends StatefulWidget {
  final String selectedBlock;
  final DateTime selectedDate;
  final void Function(int)? onAllocationChanged;

  const ManpowerOtherAllocationPage({
    Key? key,
    required this.selectedBlock,
    required this.selectedDate,
    this.onAllocationChanged,
  }) : super(key: key);

  @override
  _ManpowerOtherAllocationPageState createState() =>
      _ManpowerOtherAllocationPageState();
}

class _ManpowerOtherAllocationPageState
    extends State<ManpowerOtherAllocationPage> {
  String? selectedFactor;
  List<Map<String, dynamic>> factorData = [];

  late String selectedBlock;
  late DateTime selectedDate;
  int totalAllocated = 0;
  int totalPresent = 0;
  int otherLiveTotalled = 0;
  bool canUpload = false;

  @override
  void initState() {
    super.initState();
    selectedBlock = widget.selectedBlock;
    selectedDate = widget.selectedDate;
    _loadAll();
    loadUserInfo();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userID = prefs.getString('userID') ?? '';
      // authority = prefs.getString('authority') ?? '';
    });
  }

  Future<void> _loadAll() async {
    await _loadSavedData();
    await _calculateTotals();
  }

  Future<void> _loadSavedData() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final saved = await ManpowerOtherAllocationDatabase.instance
        .fetchAllocations(selectedBlock, dateStr);

    setState(() {
      factorData = List<Map<String, dynamic>>.from(saved);
    });
  }

  Future<void> _calculateTotals() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    final samTotal = await SamEarnerDatabase.instance.sumManpower(
      selectedBlock,
      dateStr,
    );
    final minuteTotal = await ManpowerMinuteAllocationDatabase.instance
        .sumManpower(selectedBlock, dateStr);
    final otherTotal = await ManpowerOtherAllocationDatabase.instance
        .sumManpower(selectedBlock, dateStr);
    final present = await ManpowerSummaryDatabase.instance.fetchTotalPresent(
      dateStr,
      selectedBlock,
    );

    final total = samTotal + minuteTotal + otherTotal;

    final otherLiveTotal = factorData.fold<int>(0, (sum, row) {
      final parsed = int.tryParse(row['count']?.toString() ?? '0') ?? 0;
      return sum + parsed;
    });

    setState(() {
      totalAllocated = total;
      totalPresent = present ?? 0;
      canUpload = total == present;
      otherLiveTotalled = otherLiveTotal;
    });

    widget.onAllocationChanged?.call(otherLiveTotalled);
  }

  void _addFactor(String factor) {
    if (factorData.any((entry) => entry['factor'] == factor)) return;

    final newRow = {
      'id': uuid.v4(),
      'block': widget.selectedBlock,
      'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      'factor': factor,
      'count': null,
    };

    if (factor == "TRANSFER TO OTHER BLOCK") {
      newRow['transferTo'] = null;
    }

    setState(() {
      factorData.add(newRow);
    });
  }

  void _removeFactor(String factor) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    await ManpowerOtherAllocationDatabase.instance.deleteAllocation(
      selectedBlock,
      dateStr,
      factor,
    );

    setState(() {
      factorData.removeWhere((entry) => entry['factor'] == factor);
    });

    _calculateTotals(); // update live totals
  }

  Future<void> _saveData() async {
    for (var row in factorData) {
      await ManpowerOtherAllocationDatabase.instance.insertOrUpdateAllocation(
        row,
      );
    }
    await _calculateTotals();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved successfully')));
  }

  Future<void> _uploadAllToSupabase() async {
    final supabase = Supabase.instance.client;
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    try {
      // === Step 1: Delete existing data for this block + date
      final deleteResult = await supabase
          .from('sewing_manpower_allocation')
          .delete()
          .eq('block', selectedBlock)
          .eq('date', dateStr);

      // No need to check .error — Supabase Dart now throws exceptions on failure (v1.0+)

      // === Step 2: Prepare SAM_EARNER data
      final samData = await SamEarnerDatabase.instance.fetchByBlockAndDate(
        selectedBlock,
        dateStr,
      );
      final samUploads =
          samData.map((row) {
            return {
              'allocation_type': 'SAM_EARNER',
              'block': selectedBlock,
              'date': dateStr,
              'line_no': row['lineNo'],
              'hrs8': row['hrs8'],
              'hrs4to6': row['hrs4to6'],
              'hrs6to8': row['hrs6to8'],
              'hrs8to10': row['hrs8to10'],
              'hrs10to12': row['hrs10to12'],
              'user_id': userID,
            };
          }).toList();

      // === Step 3: Prepare MINUTE data
      final minuteData = await ManpowerMinuteAllocationDatabase.instance
          .fetchByBlockAndDate(selectedBlock, dateStr);
      final minuteUploads =
          minuteData.map((row) {
            return {
              'allocation_type': 'MINUTE',
              'block': selectedBlock,
              'date': dateStr,
              'line_no': row['lineNo'],
              'hrs8': row['hrs8'],
              'hrs4to6': row['hrs4to6'],
              'hrs6to8': row['hrs6to8'],
              'hrs8to10': row['hrs8to10'],
              'hrs10to12': row['hrs10to12'],
              'user_id': userID,
            };
          }).toList();

      // === Step 4: Prepare OTHER data
      final otherUploads =
          factorData.map((row) {
            final map = {
              'allocation_type': 'OTHER',
              'block': selectedBlock,
              'date': dateStr,
              'factor': row['factor'],
              'count': row['count'],
              'user_id': userID,
            };
            if (row['factor'] == 'TRANSFER TO OTHER BLOCK') {
              map['transfer_to'] = row['transferTo'];
            }
            return map;
          }).toList();

      // === Step 5: Combine and Upload
      final allUploads = [...samUploads, ...minuteUploads, ...otherUploads];

      if (allUploads.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to upload')));
        return;
      }

      await supabase
          .from('sewing_manpower_allocation')
          .insert(allUploads); // If this fails, it will throw

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload successful')));
    } catch (e) {
      debugPrint('Upload error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Widget _buildRow(Map<String, dynamic> row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(row['factor'])),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: row['count']?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  onChanged: (countval) {
                    setState(() {
                      // store input as a string to avoid type mismatch with TextFormField
                      row['count'] = countval;
                    });
                    _calculateTotals();
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeFactor(row['factor']),
              ),
            ],
          ),
          if (row['factor'] == "TRANSFER TO OTHER BLOCK")
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Text('To Block: '),
                  DropdownButton<String>(
                    value: row['transferTo']?.toString(),
                    hint: const Text('Select Block'),
                    items:
                        [
                          "1-6",
                          "7-15",
                          "16-21",
                          "22-30",
                          "31-36",
                          "37-45",
                          "46-49",
                          "50-55",
                          "56-62",
                          "63-69",
                          "70-76",
                          "77-81",
                          "82-86",
                          "87-91",
                          "92-96",
                          "97-105",
                          "106-114",
                          "115-124",
                        ].map((block) {
                          return DropdownMenuItem<String>(
                            value: block,
                            child: Text(block),
                          );
                        }).toList(),
                    onChanged: (blockval) {
                      setState(() {
                        row['transferTo'] = blockval;
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Block: $selectedBlock | Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: selectedFactor,
                  hint: Text('Select Factor'),
                  isExpanded: true,
                  items:
                      manpowerFactors.map((factor) {
                        return DropdownMenuItem<String>(
                          value: factor,
                          child: Text(factor),
                        );
                      }).toList(),
                  onChanged:
                      (factorval) => setState(() => selectedFactor = factorval),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: Colors.blue),
                onPressed:
                    selectedFactor != null
                        ? () {
                          _addFactor(selectedFactor!);
                        }
                        : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Expanded(
          //   child: ListView(children: factorData.map(_buildRow).toList()),
          // ),
          Expanded(
            child: ListView.builder(
              itemCount: factorData.length,
              itemBuilder: (context, index) {
                final row = factorData[index];
                return KeyedSubtree(
                  key: ValueKey(
                    row['id'],
                  ), // 👈 Use a unique key to maintain state properly
                  child: _buildRow(row),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Total Manpower Allocated: $totalAllocated / $totalPresent',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveData,
                  child: Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: canUpload ? _uploadAllToSupabase : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canUpload ? Colors.green : Colors.grey,
                  ),
                  child: Text('Upload'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
