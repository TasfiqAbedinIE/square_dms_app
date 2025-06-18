// lib/subPages/non_productive_time_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:square_dms_trial/models/non_productive_time_model.dart';
import 'package:square_dms_trial/database/non_productive_time_database.dart';
import 'package:square_dms_trial/models/non_productive_time_line_model.dart';
// import 'package:square_dms_trial/database/non_productive_time_line_database.dart';

class NonProductiveTimeScreen extends StatefulWidget {
  /// The “line card” created previously. Contains id, lineNo, date, buyer, so, style.
  final NonProductiveTimeLineCard card;

  const NonProductiveTimeScreen({Key? key, required this.card})
    : super(key: key);

  @override
  State<NonProductiveTimeScreen> createState() =>
      _NonProductiveTimeScreenState();
}

class _NonProductiveTimeScreenState extends State<NonProductiveTimeScreen> {
  final _uuid = Uuid();
  List<NonProductiveEntry> entries = [];
  String userID = '';

  @override
  void initState() {
    super.initState();
    _loadEntriesForCard();
    loadUserInfo();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userID = prefs.getString('userID') ?? '';
      // authority = prefs.getString('authority') ?? '';
    });
  }

  // Load all NP entries matching this card's date and lineNo

  Future<void> _loadEntriesForCard() async {
    final db = await NonProductiveDB.openDB();

    final formattedDate = widget.card.date; // already 'yyyy-MM-dd'
    final lineNo = widget.card.lineNo;

    final result = await db.query(
      'entries',
      where: 'date = ? AND lineNo = ?',
      whereArgs: [formattedDate, lineNo],
      orderBy: 'startTime ASC',
    );

    setState(() {
      entries = result.map((e) => NonProductiveEntry.fromMap(e)).toList();
    });

    await db.close();
  }

  /// Show bottom sheet to add a new Non‐Productive entry for this card.
  void _showAddEntrySheet() {
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String selectedStartTime = '';
    String selectedEndTime = '';
    final machineNoController = TextEditingController();
    final hourlyTargetController = TextEditingController();
    String? selectedFactor;
    int? timeDifferenceInMinutes;
    String? selectedDepartment;

    List<String> departments = [
      'Planning',
      'Maintenance',
      'Quality',
      'Cutting',
      'Finishing',
      'Printing',
      'Embroidery',
      'Store',
      'Fabrics Unit',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Machine count & Target/Hour
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: machineNoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Number of Machine',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            items:
                                departments.map((dept) {
                                  return DropdownMenuItem<String>(
                                    value: dept,
                                    child: Text(dept),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setModalState(() => selectedDepartment = value);
                            },
                            decoration: const InputDecoration(
                              labelText: "Department",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Idle Factor dropdown (from local NP factors table)
                    FutureBuilder<List<String>>(
                      future: _fetchIdleFactorsFromLocalDB(),
                      builder: (ctx2, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return DropdownSearch<String>(
                          items: (filter, _) => snap.data!,
                          selectedItem: selectedFactor,
                          popupProps: const PopupProps.menu(
                            showSearchBox: true,
                          ),
                          decoratorProps: const DropDownDecoratorProps(
                            decoration: InputDecoration(
                              labelText: 'Factor',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() => selectedFactor = val);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Start & End Time pickers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Start Time
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time'),
                            Text(
                              selectedStartTime.isEmpty
                                  ? '--:--'
                                  : selectedStartTime,
                              style: const TextStyle(fontSize: 16),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                    selectedStartTime = picked.format(ctx);

                                    if (startTime != null && endTime != null) {
                                      final now = DateTime.now();
                                      final sDT = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        startTime!.hour,
                                        startTime!.minute,
                                      );
                                      final eDT = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        endTime!.hour,
                                        endTime!.minute,
                                      );
                                      timeDifferenceInMinutes =
                                          eDT.difference(sDT).inMinutes;
                                    }
                                  });
                                }
                              },
                              child: const Text('Pick Start'),
                            ),
                          ],
                        ),

                        // End Time
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time'),
                            Text(
                              selectedEndTime.isEmpty
                                  ? '--:--'
                                  : selectedEndTime,
                              style: const TextStyle(fontSize: 16),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                    selectedEndTime = picked.format(ctx);

                                    if (startTime != null && endTime != null) {
                                      final now = DateTime.now();
                                      final sDT = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        startTime!.hour,
                                        startTime!.minute,
                                      );
                                      final eDT = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        endTime!.hour,
                                        endTime!.minute,
                                      );
                                      timeDifferenceInMinutes =
                                          eDT.difference(sDT).inMinutes;
                                    }
                                  });
                                }
                              },
                              child: const Text('Pick End'),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // “Save” button
                    ElevatedButton(
                      onPressed: () async {
                        // 1) Validate factor
                        if (selectedFactor == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select an idle factor'),
                            ),
                          );
                          return;
                        }
                        // 2) Validate time pickers
                        if (startTime == null || endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please pick both start and end time',
                              ),
                            ),
                          );
                          return;
                        }

                        // 3) Ensure start < end
                        final now = DateTime.now();
                        final sDT = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          startTime!.hour,
                          startTime!.minute,
                        );
                        final eDT = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          endTime!.hour,
                          endTime!.minute,
                        );
                        if (!sDT.isBefore(eDT)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Start time must be earlier than end time',
                              ),
                            ),
                          );
                          return;
                        }

                        // 4) Calculate duration
                        final durationMins = eDT.difference(sDT).inMinutes;

                        // 5) Validate machine count
                        final machineCount =
                            int.tryParse(machineNoController.text) ?? 0;
                        if (machineCount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid number of machines'),
                            ),
                          );
                          return;
                        }

                        // 6) Build the new entry
                        final newEntry = NonProductiveEntry(
                          id: _uuid.v4(),
                          lineNo: widget.card.lineNo,
                          date: widget.card.date,
                          startTime: selectedStartTime,
                          endTime: selectedEndTime,
                          machine_num: machineCount,
                          reason: selectedFactor!,
                          durationMinutes: durationMins,
                          totalNP: machineCount * durationMins,
                          totalLostPcs:
                              ((machineCount * durationMins) /
                                  widget.card.smv) *
                              3,
                          machine_code: widget.card.id,
                          deptid: userID,
                          res_dept:
                              selectedDepartment
                                  .toString(), // if needed, fill your deptId logic
                        );

                        // 7) Insert into local SQLite
                        try {
                          await NonProductiveDB.insertEntry(newEntry);
                          Navigator.pop(ctx);
                          await _loadEntriesForCard();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Entry saved successfully'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving entry: $e')),
                          );
                        }
                      },
                      child: const Text('Save Entry'),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void downloadOTFactors(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final db = await openDatabase('NonProductive.db');

    try {
      // Fetch from Supabase
      final data = await supabase
          .from('non_productive_time_factors')
          .select('id, idle_factors');

      // Drop and recreate local table
      await db.execute('DROP TABLE IF EXISTS non_productive_factors');
      await db.execute('''
      CREATE TABLE non_productive_factors (
        id INTEGER PRIMARY KEY,
        idle_factors TEXT
      )
    ''');

      // Insert fetched data into local DB
      for (final row in data) {
        await db.insert('non_productive_factors', {
          'id': row['id'],
          'idle_factors': row['idle_factors'],
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OT Factors downloaded successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to download OT Factors: $e")),
      );
    } finally {
      await db.close();
    }
  }

  /// Fetch all idle factors from the local NP‐factors table
  Future<List<String>> _fetchIdleFactorsFromLocalDB() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(path.join(dbPath, 'NonProductive.db'));

    final rows = await db.query('non_productive_factors');
    await db.close();

    return rows.map((r) => r['idle_factors'] as String).toList();
  }

  /// Delete one entry by id
  Future<void> _deleteEntry(BuildContext context, String id) async {
    await NonProductiveDB.deleteEntry(id);
    await _loadEntriesForCard();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
  }

  /// Show edit‐entry sheet (similar to add, but prefilled)
  void _showEditEntrySheet(NonProductiveEntry entry) {
    final machineNoController = TextEditingController(
      text: entry.machine_num.toString(),
    );
    final hourlyTargetController = TextEditingController();
    TimeOfDay? startTime = _parseTime(entry.startTime);
    TimeOfDay? endTime = _parseTime(entry.endTime);
    String selectedStartTime = entry.startTime;
    String selectedEndTime = entry.endTime;
    String selectedFactor = entry.reason;
    int? timeDifferenceInMinutes;
    String? selectedDepartment = entry.res_dept;

    List<String> departments = [
      'Planning',
      'Maintenance',
      'Quality',
      'Cutting',
      'Finishing',
      'Printing',
      'Embroidery',
      'Store',
      'Fabrics Unit',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Machine & Target
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: machineNoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Number of Machine',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            items:
                                departments.map((dept) {
                                  return DropdownMenuItem<String>(
                                    value: dept,
                                    child: Text(dept),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setModalState(() => selectedDepartment = value!);
                            },
                            decoration: const InputDecoration(
                              labelText: "Department",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Idle Factor dropdown (prefilled)
                    FutureBuilder<List<String>>(
                      future: _fetchIdleFactorsFromLocalDB(),
                      builder: (ctx2, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return DropdownSearch<String>(
                          items: (filter, _) => snap.data!,
                          selectedItem: selectedFactor,
                          popupProps: const PopupProps.menu(
                            showSearchBox: true,
                          ),
                          decoratorProps: const DropDownDecoratorProps(
                            decoration: InputDecoration(
                              labelText: 'Factor',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() => selectedFactor = val!);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Start & End Time pickers, prefilled
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Start Time
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time'),
                            Text(
                              selectedStartTime,
                              style: const TextStyle(fontSize: 16),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: startTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                    selectedStartTime = picked.format(ctx);
                                  });
                                }
                              },
                              child: const Text('Pick Start'),
                            ),
                          ],
                        ),

                        // End Time
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time'),
                            Text(
                              selectedEndTime,
                              style: const TextStyle(fontSize: 16),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: endTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                    selectedEndTime = picked.format(ctx);
                                  });
                                }
                              },
                              child: const Text('Pick End'),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // “Update” button
                    ElevatedButton(
                      onPressed: () async {
                        // 1) Validate start/end times
                        if (startTime == null || endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please pick both start and end time',
                              ),
                            ),
                          );
                          return;
                        }
                        // 2) Ensure start < end
                        final now = DateTime.now();
                        final sDT = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          startTime!.hour,
                          startTime!.minute,
                        );
                        final eDT = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          endTime!.hour,
                          endTime!.minute,
                        );
                        if (!sDT.isBefore(eDT)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Start time must be earlier than end time',
                              ),
                            ),
                          );
                          return;
                        }

                        // 3) Calculate duration
                        final durationMins = eDT.difference(sDT).inMinutes;

                        // 4) Validate machine count
                        final machineCount =
                            int.tryParse(machineNoController.text) ?? 0;
                        if (machineCount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid number of machines'),
                            ),
                          );
                          return;
                        }

                        // 5) Build the updated entry
                        final updated = NonProductiveEntry(
                          id: entry.id,
                          lineNo: entry.lineNo,
                          date: entry.date,
                          startTime: selectedStartTime,
                          endTime: selectedEndTime,
                          machine_num: machineCount,
                          reason: selectedFactor,
                          durationMinutes: durationMins,
                          totalNP: machineCount * durationMins,
                          totalLostPcs:
                              ((double.tryParse(hourlyTargetController.text) ??
                                      0) /
                                  60) *
                              (machineCount * durationMins),
                          machine_code: entry.machine_code,
                          deptid: entry.deptid,
                          res_dept: entry.res_dept,
                        );

                        try {
                          await NonProductiveDB.updateEntry(updated);
                          Navigator.pop(ctx);
                          await _loadEntriesForCard();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Entry updated successfully'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating entry: $e')),
                          );
                        }
                      },
                      child: const Text('Update Entry'),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Helper to parse stored “hh:mm AM/PM” back into TimeOfDay
  TimeOfDay? _parseTime(String t) {
    try {
      final dt = DateFormat.jm().parse(t);
      return TimeOfDay.fromDateTime(dt);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 179, 193),
        foregroundColor: Colors.black,
        title: const Text("Non-Productive Time"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR',
            onPressed: () {
              // Launch QR code scanner
              // launchQRScanner(context); // ← define this method
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // ── HEADER: show card’s reference + details ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Line: ${widget.card.lineNo}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buyer: ${widget.card.buyer}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SO: ${widget.card.soNumber}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Style: ${widget.card.style}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                const SizedBox(height: 4),
                Text(
                  'Date: ${widget.card.date}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          const Divider(),

          // ── LIST OF EXISTING ENTRIES ──
          Expanded(
            child:
                entries.isEmpty
                    ? const Center(child: Text("No entries yet"))
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final e = entries[index];

                        return Dismissible(
                          key: Key(e.id),

                          // Green “Edit” background when swiping right:
                          background: Container(
                            color: Colors.green,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),

                          // Red “Delete” background when swiping left:
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),

                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // ► Swiped right: invoke edit sheet but do NOT dismiss
                              _showEditEntrySheet(e);
                              return false; // keep the item in the list
                            }

                            // ◄ Swiped left: show delete confirmation dialog
                            if (direction == DismissDirection.endToStart) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      title: const Text("Confirm Delete"),
                                      content: const Text(
                                        "Do you want to delete this entry?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirmed == true) {
                                await _deleteEntry(context, e.id);
                              }
                              return confirmed;
                            }

                            return false;
                          },

                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            elevation: 2,
                            child: ListTile(
                              title: Text(
                                "${e.startTime} – ${e.endTime}  (${e.durationMinutes} min)",
                              ),
                              subtitle: Text(
                                "Machines: ${e.machine_num}   Factor: ${e.reason}",
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),

      // ── FAB to add a new entry ──
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 255, 179, 193),
        foregroundColor: Colors.black,
        onPressed: _showAddEntrySheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}
