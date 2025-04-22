import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:square_dms_trial/database/sewing_process_database.dart';
import 'package:square_dms_trial/models/sewing_process_model.dart';

class SkillMatrixTimeStudyPage extends StatefulWidget {
  const SkillMatrixTimeStudyPage({super.key});

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
  List<int> lapTimestamps = [];

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

  void startStopwatch() {
    if (!stopwatch.isRunning) {
      stopwatch.start();
      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        final duration = stopwatch.elapsed;
        setState(() {
          elapsedTime =
              "${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
        });
      });
    }
  }

  void recordLap() {
    if (!stopwatch.isRunning) return;
    setState(() {
      lapTimestamps.add(stopwatch.elapsedMilliseconds);
    });
  }

  void stopStopwatch() {
    if (stopwatch.isRunning) {
      stopwatch.stop();
      timer?.cancel();
    }
  }

  void resetStopwatch() {
    stopwatch.reset();
    timer?.cancel();
    setState(() {
      elapsedTime = "00:00:00";
      lapTimestamps.clear();
    });
  }

  double get averageLapTime {
    if (lapTimestamps.length <= 1) return 0;
    List<int> diffs = [];
    for (int i = 1; i < lapTimestamps.length; i++) {
      diffs.add(lapTimestamps[i] - lapTimestamps[i - 1]);
    }
    return diffs.reduce((a, b) => a + b) / diffs.length / 1000.0;
  }

  int get capacityPerHour {
    if (averageLapTime == 0) return 0;
    return (3600 / averageLapTime).floor();
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

            /// Process + Machine Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownSearch<String>(
                    items: (filter, infiniteScrollProps) => processNames,
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownSearch<String>(
                    items: (filter, infiniteScrollProps) => machines,
                    selectedItem: selectedMachine,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: "Machine"),
                    ),
                    onChanged:
                        (value) => setState(() => selectedMachine = value),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// SubProcess + Form Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownSearch<String>(
                    items: (filter, infiniteScrollProps) => processNames,
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
                Expanded(
                  flex: 1,
                  child: DropdownSearch<String>(
                    items: (filter, infiniteScrollProps) => forms,
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
                itemCount: lapTimestamps.length,
                itemBuilder: (context, index) {
                  final lapTime =
                      index == 0
                          ? lapTimestamps[0] / 1000.0
                          : (lapTimestamps[index] - lapTimestamps[index - 1]) /
                              1000.0;
                  final isLast = index == lapTimestamps.length - 1;

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        "Lap ${index + 1}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        "${lapTime.toStringAsFixed(2)} seconds",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing:
                          isLast
                              ? IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    lapTimestamps.removeAt(index);
                                  });
                                },
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
              // color: Colors.white,
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
                      Text("Laps: ${lapTimestamps.length}"),
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
                        onPressed: () {
                          // Save logic here
                        },
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
