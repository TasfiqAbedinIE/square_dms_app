import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:square_dms_trial/database/sewing_process_database.dart';
import 'package:square_dms_trial/database/capacity_record_database.dart';
import 'package:square_dms_trial/models/sewing_process_model.dart';
import 'package:square_dms_trial/models/capacity_record_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SkillMatrixTimeStudyPage extends StatefulWidget {
  final CapacityRecord record;
  const SkillMatrixTimeStudyPage({super.key, required this.record});

  @override
  State<SkillMatrixTimeStudyPage> createState() =>
      _SkillMatrixTimeStudyPageState();
}

class _SkillMatrixTimeStudyPageState extends State<SkillMatrixTimeStudyPage> {
  final TextEditingController operatorController = TextEditingController();

  List<SewingProcess> allProcesses = [];
  List<String> processNames = [];
  List<String> machines = [];
  List<String> forms = [];

  String? selectedProcess;
  String? selectedMachine;
  String? selectedSubProcess;
  String? selectedForm;

  Stopwatch stopwatch = Stopwatch();
  Timer? timer;
  String elapsedTime = "00:00:00";

  List<int> allLapTimestamps = []; // raw timestamps
  List<int> displayedLapIndexes = []; // indexes into allLapTimestamps
  List<int?> lapBaseTimestamps = []; // base timestamp for each displayed lap
  int? nextLapBaseTimestamp;

  @override
  void initState() {
    super.initState();
    loadProcessData();
  }

  Future<void> loadProcessData() async {
    final db = await SewingProcessDatabase.instance.database;
    final processes = await SewingProcessDatabase.instance.fetchProcesses(db);
    setState(() {
      allProcesses = processes;
      processNames = processes.map((e) => e.processName).toSet().toList();
    });
  }

  // void startStopwatch() {
  //   if (!stopwatch.isRunning) {
  //     stopwatch.start();
  //     timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
  //       final d = stopwatch.elapsed;
  //       setState(() {
  //         elapsedTime =
  //             "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  //       });
  //     });
  //   }
  // }

  void startStopwatch() {
    if (!stopwatch.isRunning) {
      stopwatch.start();
      // Every 10ms is enough to update centiseconds
      timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        final d = stopwatch.elapsed;
        final h = d.inHours.toString().padLeft(2, '0');
        final m = (d.inMinutes % 60).toString().padLeft(2, '0');
        final s = (d.inSeconds % 60).toString().padLeft(2, '0');
        // Compute centiseconds: two‐digit fraction of a second
        final cs = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
        setState(() {
          // Format: HH:MM:SS.cc
          elapsedTime = '$m:$s.$cs';
        });
      });
    }
  }

  void recordLap() {
    if (!stopwatch.isRunning) return;
    final ts = stopwatch.elapsedMilliseconds;
    allLapTimestamps.add(ts);
    setState(() {
      displayedLapIndexes.add(allLapTimestamps.length - 1);
      // assign base for this lap
      lapBaseTimestamps.add(nextLapBaseTimestamp);
      nextLapBaseTimestamp = null;
    });
  }

  void deleteLastLap() {
    if (displayedLapIndexes.isNotEmpty) {
      setState(() {
        final idx = displayedLapIndexes.removeLast();
        nextLapBaseTimestamp = allLapTimestamps[idx];
        lapBaseTimestamps.removeLast();
      });
    }
  }

  double getLapTime(int i) {
    final ts = allLapTimestamps[displayedLapIndexes[i]];
    final base = lapBaseTimestamps[i];
    if (base != null) {
      return (ts - base) / 1000.0;
    }
    if (i == 0) {
      return ts / 1000.0;
    }
    final prevTs = allLapTimestamps[displayedLapIndexes[i - 1]];
    return (ts - prevTs) / 1000.0;
  }

  void stopStopwatch() {
    if (stopwatch.isRunning) {
      stopwatch.stop();
      timer?.cancel();
    }
  }

  void resetStopwatch() {
    stopwatch.stop();
    stopwatch.reset();
    timer?.cancel();
    setState(() {
      elapsedTime = "00:00:00";
      allLapTimestamps.clear();
      displayedLapIndexes.clear();
      lapBaseTimestamps.clear();
      nextLapBaseTimestamp = null;
    });
  }

  double get averageLapTime {
    if (displayedLapIndexes.isEmpty) return 0;
    double tot = 0;
    for (int i = 0; i < displayedLapIndexes.length; i++) {
      tot += getLapTime(i);
    }
    return tot / displayedLapIndexes.length;
  }

  int get capacityPerHour {
    final avg = averageLapTime;
    return avg == 0 ? 0 : (3600 / avg).floor();
  }

  // @override
  // void dispose() {
  //   stopwatch.stop();
  //   timer?.cancel();
  //   super.dispose();
  // }

  Future<void> saveRecord() async {
    if (operatorController.text.isEmpty ||
        selectedProcess == null ||
        selectedMachine == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    final processName = "$selectedProcess + $selectedSubProcess";

    final operatorIdTrimmed = operatorController.text.trim();
    final db = await CapacityRecordDatabase.instance.database;

    final existing = await db.query(
      'skillMatrixRecords',
      where: 'referenceNumber = ? AND operatorID = ?',
      whereArgs: [widget.record.referenceNumber, operatorIdTrimmed],
    );

    if (existing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This Operator ID is already recorded for this reference.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isuserID = prefs.getString('userID') ?? '';

    final newSkillRecord = {
      'referenceNumber': widget.record.referenceNumber,
      'lineNumber': widget.record.lineNumber,
      'buyer': widget.record.buyer,
      'salesDocument': widget.record.salesDocument,
      'style': widget.record.style,
      'item': widget.record.item,
      'layoutTarget': widget.record.layoutTarget,
      'date': widget.record.date,
      'operatorID': operatorIdTrimmed,
      'processName': processName,
      'machine': selectedMachine,
      'form': selectedForm ?? '',
      'lapCount': displayedLapIndexes.length,
      'avgCycle': averageLapTime.toStringAsFixed(2),
      'capacityPH': capacityPerHour,
      'deptid': isuserID,
    };

    await db.insert('skillMatrixRecords', newSkillRecord);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Record saved successfully")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Time Study")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: operatorController,
              decoration: const InputDecoration(labelText: "Operator ID"),
            ),
            const SizedBox(height: 16),
            DropdownSearch<String>(
              items: (filter, _) => processNames,
              selectedItem: selectedProcess,
              popupProps: const PopupProps.menu(showSearchBox: true),
              decoratorProps: const DropDownDecoratorProps(
                decoration: InputDecoration(labelText: "Process"),
              ),
              onChanged: (value) {
                setState(() {
                  selectedProcess = value;
                  machines =
                      allProcesses
                          .where((e) => e.processName == value)
                          .map((e) => e.machine)
                          .toSet()
                          .toList();
                  selectedMachine = null;
                });
              },
            ),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownSearch<String>(
                    items: (filter, _) => machines,
                    selectedItem: selectedMachine,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: "Machine"),
                    ),
                    onChanged:
                        (value) => setState(() => selectedMachine = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownSearch<String>(
                    items: (filter, _) => forms,
                    selectedItem: selectedForm,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: "Form"),
                    ),
                    onChanged: (value) => setState(() => selectedForm = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownSearch<String>(
                    items: (filter, _) => processNames,
                    selectedItem: selectedSubProcess,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: "SubProcess"),
                    ),
                    onChanged: (value) {
                      setState(() {
                        selectedSubProcess = value;
                        forms =
                            allProcesses
                                .where((e) => e.processName == value)
                                .map((e) => e.form)
                                .toSet()
                                .toList();
                        selectedForm = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                elapsedTime,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: displayedLapIndexes.length,
                itemBuilder: (ctx, i) {
                  return Card(
                    child: ListTile(
                      leading: Text('Lap ${i + 1}'),
                      title: Text('${getLapTime(i).toStringAsFixed(2)} sec'),
                      trailing:
                          i == displayedLapIndexes.length - 1
                              ? IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: deleteLastLap,
                              )
                              : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: startStopwatch,
                        child: const Text("Start"),
                      ),
                      ElevatedButton(
                        onPressed: recordLap,
                        child: const Text("Lap"),
                      ),
                      ElevatedButton(
                        onPressed: stopStopwatch,
                        child: const Text("End"),
                      ),
                      ElevatedButton(
                        onPressed: resetStopwatch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text("Reset"),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Laps: ${displayedLapIndexes.length}"),
                      Text("Avg: ${averageLapTime.toStringAsFixed(2)} sec"),
                      Text("Cap/hr: $capacityPerHour"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: saveRecord,
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
