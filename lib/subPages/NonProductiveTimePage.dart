import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/models/non_productive_time_model.dart';
import 'package:square_dms_trial/database/non_productive_time_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart';
import 'package:square_dms_trial/service/qr_scanner_page.dart';
import 'package:square_dms_trial/subPages/NonProductiveTimeReportPage.dart';

class NonProductiveTimeScreen extends StatefulWidget {
  const NonProductiveTimeScreen({super.key});

  @override
  State<NonProductiveTimeScreen> createState() =>
      _NonProductiveTimeScreenState();
}

class _NonProductiveTimeScreenState extends State<NonProductiveTimeScreen> {
  List<NonProductiveEntry> entries = [];
  DateTime selectedDate = DateTime.now();
  String? selectedBlock;
  bool isLoading = true;

  List<String> blockOptions = [];
  bool isMasterUser = false;
  final uuid = Uuid();
  String userID = '';

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

  @override
  void initState() {
    super.initState();
    loadEntries();
    _fetchUserWorkingArea();
    loadUserInfo();
  }

  Future<void> loadEntries() async {
    final db = await openDatabase(
      join(await getDatabasesPath(), 'NonProductive.db'),
    );
    print(selectedDate);
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    final result = await db.query(
      'entries',
      where: 'date = ?',
      whereArgs: [formattedDate],
    );

    setState(() {
      entries = result.map((e) => NonProductiveEntry.fromMap(e)).toList();
    });

    await db.close();
  }

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
        debugPrint('No working area found for user $storedUserId');
        setState(() {
          blockOptions = [];
          isLoading = false;
        });
        return;
      }

      final rawArea = response['working_area'];
      List<dynamic> parsedArea = [];

      if (rawArea is String) {
        parsedArea = jsonDecode(rawArea);
      } else if (rawArea is List) {
        parsedArea = rawArea;
      }
      print(parsedArea);

      List<String> areaList = parsedArea.cast<String>().toList();

      setState(() {
        isMasterUser = areaList.contains('MASTER');
        blockOptions = isMasterUser ? blockLines.keys.toList() : areaList;

        if (blockOptions.isNotEmpty) {
          selectedBlock = blockOptions.first;
          _initControllers(selectedBlock!);
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching working area: $e');
      // _showNoWorkingAreaSnackbar();
      setState(() {
        blockOptions = [];
        isLoading = false;
      });
    }
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userID = prefs.getString('userID') ?? '';
      // authority = prefs.getString('authority') ?? '';
    });
  }

  void _initControllers(String block) {
    final lines = blockLines[block] ?? [];
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final format = DateFormat.jm(); // handles AM/PM
      final dt = format.parse(timeStr);
      return TimeOfDay.fromDateTime(dt);
    } catch (_) {
      return null;
    }
  }

  void showEditEntrySheet(BuildContext context, NonProductiveEntry entry) {
    final lineController = TextEditingController(text: entry.lineNo.toString());
    final reasonController = TextEditingController(text: entry.reason);
    TimeOfDay? startTime = _parseTime(entry.startTime);
    TimeOfDay? endTime = _parseTime(entry.endTime);
    String selectedStartTime = entry.startTime;
    String selectedEndTime = entry.endTime;
    final hourlyTargetController = TextEditingController();
    final machineNoController = TextEditingController(
      text: entry.machine_num.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: machineNoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Number of Machine",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: hourlyTargetController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Target/Hour",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Start Time"),
                            Text(selectedStartTime),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime ?? TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                    selectedStartTime = picked.format(context);
                                  });
                                }
                              },
                              child: const Text("Pick Start"),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("End Time"),
                            Text(selectedEndTime),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      endTime ?? TimeOfDay(hour: 17, minute: 0),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                    selectedEndTime = picked.format(context);
                                  });
                                }
                              },
                              child: const Text("Pick End"),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        // Check if time parsing failed
                        if (startTime == null || endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select both start and end time',
                              ),
                            ),
                          );
                          return;
                        }

                        // Ensure formatted strings are up-to-date
                        selectedStartTime =
                            selectedStartTime.isEmpty
                                ? startTime!.format(context)
                                : selectedStartTime;
                        selectedEndTime =
                            selectedEndTime.isEmpty
                                ? endTime!.format(context)
                                : selectedEndTime;

                        // Construct datetime for duration calc
                        final now = DateTime.now();
                        final startDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          startTime!.hour,
                          startTime!.minute,
                        );
                        final endDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          endTime!.hour,
                          endTime!.minute,
                        );

                        // Validate duration
                        if (!startDateTime.isBefore(endDateTime)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Start time must be earlier than end time',
                              ),
                            ),
                          );
                          return;
                        }

                        final durationMinutes =
                            endDateTime.difference(startDateTime).inMinutes;

                        // Optional: Validate machine count
                        final machineCount =
                            int.tryParse(machineNoController.text) ?? 0;
                        if (machineCount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid machine number'),
                            ),
                          );
                          return;
                        }

                        try {
                          final hourlyTarget =
                              double.tryParse(hourlyTargetController.text) ?? 0;

                          final updated = NonProductiveEntry(
                            id: entry.id,
                            lineNo: int.tryParse(lineController.text) ?? 0,
                            date: entry.date,
                            startTime: selectedStartTime,
                            endTime: selectedEndTime,
                            machine_num: machineCount,
                            reason: reasonController.text,
                            durationMinutes: durationMinutes,
                            totalNP: machineCount * durationMinutes,
                            totalLostPcs:
                                (hourlyTarget / 60) *
                                machineCount *
                                durationMinutes,
                            machine_code: entry.machine_code,
                            deptid: userID,
                          );

                          await NonProductiveDB.updateEntry(updated);

                          Navigator.pop(context);
                          loadEntries();

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
                      child: const Text("Update"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showAddEntrySheet(BuildContext context) {
    int? selectedLine;
    String? selectedDepartment;
    String? selectedFactor;
    DateTime entryDate = selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String selectedStartTime = '';
    String selectedEndTime = '';
    final machineNoController = TextEditingController();
    final hourlyTargetController = TextEditingController();
    int? timeDifferenceInMinutes;
    final int durationMinutes;

    final List<int> userLines =
        blockOptions
            .expand<int>((block) => blockLines[block]?.cast<int>() ?? <int>[])
            .toSet()
            .toList()
          ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date: ${DateFormat('yyyy-MM-dd').format(entryDate)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: entryDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                entryDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text("Change"),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedLine,
                            items:
                                userLines.map((line) {
                                  return DropdownMenuItem<int>(
                                    value: line,
                                    child: Text('$line'),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setModalState(() => selectedLine = value);
                            },
                            decoration: const InputDecoration(
                              labelText: "Line No",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: machineNoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Number of Machine",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: hourlyTargetController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Target/Hour",
                            ),
                          ),
                        ),
                      ],
                    ),

                    FutureBuilder<List<String>>(
                      future: fetchIdleFactorsFromLocalDB(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        return DropdownSearch<String>(
                          items: (filter, _) => snapshot.data!,
                          selectedItem: selectedFactor,
                          popupProps: const PopupProps.menu(
                            showSearchBox: true,
                          ),
                          decoratorProps: const DropDownDecoratorProps(
                            decoration: InputDecoration(labelText: "Factor"),
                          ),
                          onChanged: (value) {
                            setModalState(() => selectedFactor = value);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Start Time"),
                            Text(
                              selectedStartTime.isEmpty
                                  ? "--:--"
                                  : selectedStartTime,
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                    selectedStartTime = picked.format(context);

                                    if (startTime != null && endTime != null) {
                                      final now = DateTime.now();
                                      final start = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        startTime!.hour,
                                        startTime!.minute,
                                      );
                                      final end = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        endTime!.hour,
                                        endTime!.minute,
                                      );
                                      timeDifferenceInMinutes =
                                          end.difference(start).inMinutes;
                                    }
                                  });
                                }
                              },
                              child: const Text("Pick Start"),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("End Time"),
                            Text(
                              selectedEndTime.isEmpty
                                  ? "--:--"
                                  : selectedEndTime,
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                    selectedEndTime = picked.format(context);

                                    if (startTime != null && endTime != null) {
                                      final now = DateTime.now();
                                      final start = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        startTime!.hour,
                                        startTime!.minute,
                                      );
                                      final end = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        endTime!.hour,
                                        endTime!.minute,
                                      );
                                      timeDifferenceInMinutes =
                                          end.difference(start).inMinutes;
                                    }
                                  });
                                }
                              },
                              child: const Text("Pick End"),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        // await NonProductiveDB.resetEntriesTable();
                        if (selectedLine == null ||
                            selectedDepartment == null ||
                            selectedFactor == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all required fields'),
                            ),
                          );
                          return;
                        }
                        if (startTime == null || endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select both start and end time',
                              ),
                            ),
                          );
                          return;
                        }

                        final now = DateTime.now();
                        final startDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          startTime!.hour,
                          startTime!.minute,
                        );
                        final endDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          endTime!.hour,
                          endTime!.minute,
                        );

                        final durationMinutes =
                            endDateTime.difference(startDateTime).inMinutes;

                        if (!startDateTime.isBefore(endDateTime)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Start time must be earlier than end time',
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          final newEntry = NonProductiveEntry(
                            id: uuid.v4(),
                            lineNo: selectedLine!,
                            date: DateFormat('yyyy-MM-dd').format(entryDate),
                            startTime: selectedStartTime,
                            endTime: selectedEndTime,
                            machine_num:
                                int.tryParse(machineNoController.text) ?? 0,
                            reason: selectedFactor!,
                            durationMinutes: durationMinutes,
                            totalNP:
                                (int.tryParse(machineNoController.text) ?? 0) *
                                durationMinutes,
                            totalLostPcs:
                                ((double.tryParse(
                                          hourlyTargetController.text,
                                        ) ??
                                        0) /
                                    60) *
                                ((int.tryParse(machineNoController.text) ?? 0) *
                                    durationMinutes),
                            machine_code: '',
                            deptid: userID,
                          );

                          await NonProductiveDB.insertEntry(newEntry);
                          Navigator.pop(context);
                          loadEntries();
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
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showAddEntrySheetMB(BuildContext context, {String? qrValue}) {
    int? selectedLine;
    String? selectedDepartment;
    String? selectedFactor;
    DateTime entryDate = selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String selectedStartTime = '';
    String selectedEndTime = '';
    final machineNoController = TextEditingController(text: '1');
    final hourlyTargetController = TextEditingController();
    int? timeDifferenceInMinutes;
    final int durationMinutes;

    final List<int> userLines =
        blockOptions
            .expand<int>((block) => blockLines[block]?.cast<int>() ?? <int>[])
            .toSet()
            .toList()
          ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date: ${DateFormat('yyyy-MM-dd').format(entryDate)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: entryDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                entryDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text("Change"),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedLine,
                            items:
                                userLines.map((line) {
                                  return DropdownMenuItem<int>(
                                    value: line,
                                    child: Text('$line'),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setModalState(() => selectedLine = value);
                            },
                            decoration: const InputDecoration(
                              labelText: "Line No",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                              labelText: "Responsible Department",
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: machineNoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Number of Machine",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: hourlyTargetController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Target/Hour",
                            ),
                          ),
                        ),
                      ],
                    ),

                    FutureBuilder<List<String>>(
                      future: fetchIdleFactorsFromLocalDB(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        return DropdownSearch<String>(
                          items: (filter, _) => snapshot.data!,
                          selectedItem: selectedFactor,
                          popupProps: const PopupProps.menu(
                            showSearchBox: true,
                          ),
                          decoratorProps: const DropDownDecoratorProps(
                            decoration: InputDecoration(labelText: "Factor"),
                          ),
                          onChanged: (value) {
                            setModalState(() => selectedFactor = value);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Start Time"),
                            Text(
                              selectedStartTime.isEmpty
                                  ? "--:--"
                                  : selectedStartTime,
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                    selectedStartTime = picked.format(context);

                                    if (startTime != null && endTime != null) {
                                      final now = DateTime.now();
                                      final start = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        startTime!.hour,
                                        startTime!.minute,
                                      );
                                      final end = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        endTime!.hour,
                                        endTime!.minute,
                                      );
                                      timeDifferenceInMinutes =
                                          end.difference(start).inMinutes;
                                    }
                                  });
                                }
                              },
                              child: const Text("Pick Start"),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("End Time"),
                            Text(
                              selectedEndTime.isEmpty
                                  ? "--:--"
                                  : selectedEndTime,
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                    selectedEndTime = picked.format(context);

                                    if (startTime != null && endTime != null) {
                                      final now = DateTime.now();
                                      final start = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        startTime!.hour,
                                        startTime!.minute,
                                      );
                                      final end = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        endTime!.hour,
                                        endTime!.minute,
                                      );
                                      timeDifferenceInMinutes =
                                          end.difference(start).inMinutes;
                                    }
                                  });
                                }
                              },
                              child: const Text("Pick End"),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        // await NonProductiveDB.resetEntriesTable();
                        if (selectedLine == null ||
                            selectedDepartment == null ||
                            selectedFactor == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all required fields'),
                            ),
                          );
                          return;
                        }
                        if (startTime == null || endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select both start and end time',
                              ),
                            ),
                          );
                          return;
                        }

                        final now = DateTime.now();
                        final startDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          startTime!.hour,
                          startTime!.minute,
                        );
                        final endDateTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          endTime!.hour,
                          endTime!.minute,
                        );

                        final durationMinutes =
                            endDateTime.difference(startDateTime).inMinutes;

                        if (!startDateTime.isBefore(endDateTime)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Start time must be earlier than end time',
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          final newEntry = NonProductiveEntry(
                            id: uuid.v4(),
                            lineNo: selectedLine!,
                            date: DateFormat('yyyy-MM-dd').format(entryDate),
                            startTime: selectedStartTime,
                            endTime: selectedEndTime,
                            machine_num:
                                int.tryParse(machineNoController.text) ?? 0,
                            reason: selectedFactor!,
                            durationMinutes: durationMinutes,
                            totalNP:
                                (int.tryParse(machineNoController.text) ?? 0) *
                                durationMinutes,
                            totalLostPcs:
                                ((double.tryParse(
                                          hourlyTargetController.text,
                                        ) ??
                                        0) /
                                    60) *
                                ((int.tryParse(machineNoController.text) ?? 0) *
                                    durationMinutes),
                            machine_code: qrValue ?? '',
                            deptid: userID,
                          );

                          await NonProductiveDB.insertEntry(newEntry);
                          Navigator.pop(context);
                          loadEntries();
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
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> deleteEntry(BuildContext context, String id) async {
    await NonProductiveDB.deleteEntry(id);
    loadEntries();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
  }

  void launchQRScanner(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );

    if (result != null && context.mounted) {
      debugPrint("Scanned: $result");

      // Automatically open the bottom sheet with scanned data
      Future.delayed(Duration.zero, () {
        showAddEntrySheetMB(context, qrValue: result);
      });
    }
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

  Future<List<String>> fetchIdleFactorsFromLocalDB() async {
    final db = await openDatabase('NonProductive.db');
    final result = await db.query('non_productive_factors');
    await db.close();
    return result.map((row) => row['idle_factors'] as String).toList();
  }

  void uploadToCloudForDate(BuildContext context, DateTime date) async {
    final client = Supabase.instance.client;
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final dbPath = await getDatabasesPath();
    final db = await openDatabase(join(dbPath, 'NonProductive.db'));

    try {
      // 1. Get all entries for the selected date
      final localEntries = await db.query(
        'entries',
        where: 'date = ?',
        whereArgs: [formattedDate],
      );

      if (localEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No entries found for $formattedDate")),
        );
        return;
      }

      // 2. Fetch already uploaded IDs from Supabase
      final uploaded = await client
          .from('non_productive_time')
          .select('id')
          .inFilter('id', localEntries.map((e) => e['id']).toList());

      final uploadedIds = uploaded.map((e) => e['id'].toString()).toSet();

      // 3. Filter out duplicates
      final newEntries =
          localEntries
              .where((entry) => !uploadedIds.contains(entry['id']))
              .toList();

      if (newEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("All entries for $formattedDate already uploaded"),
          ),
        );
        return;
      }

      // 4. Upload filtered entries
      final insertPayload =
          newEntries
              .map(
                (e) => {
                  'id': e['id'],
                  'lineNo': e['lineNo'],
                  'date': e['date'],
                  'startTime': e['startTime'],
                  'endTime': e['endTime'],
                  'machine_num': e['machine_num'],
                  'reason': e['reason'],
                  'durationMinutes': e['durationMinutes'],
                  'totalNP': e['totalNP'],
                  'totalLostPcs': e['totalLostPcs'],
                  'deptid': e['deptid'],
                },
              )
              .toList();

      await client.from('non_productive_time').insert(insertPayload);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Uploaded ${newEntries.length} new record(s) for $formattedDate",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      await db.close();
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
              launchQRScanner(context); // ← define this method
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download OT Factor',
            onPressed: () {
              // Download OT factors
              downloadOTFactors(context); // ← define this method
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Lost Time Report',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LostTimeReportPage()),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
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
                        loadEntries(); // Optional: reload filtered entries for the date
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 10),
                          Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    uploadToCloudForDate(
                      context,
                      selectedDate,
                    ); // Define this method
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text("Save"),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                entries.isEmpty
                    ? const Center(child: Text("No records found"))
                    : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Dismissible(
                          key: Key(entry.id.toString()),
                          background: Container(
                            color: Colors.green,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
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
                            if (direction == DismissDirection.endToStart) {
                              final confirm = await showDialog(
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
                              if (confirm) {
                                await deleteEntry(context, entry.id);
                              }
                              return confirm;
                            } else {
                              showEditEntrySheet(context, entry);
                              return false;
                            }
                          },
                          child: Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              title: Text(
                                "Line ${entry.lineNo} - ${entry.reason}",
                              ),
                              subtitle: Text(
                                "${entry.date} | ${entry.startTime} - ${entry.endTime} | Duration: ${entry.durationMinutes} min",
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 255, 179, 193),
        onPressed: () => showAddEntrySheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
