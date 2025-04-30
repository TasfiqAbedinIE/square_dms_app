import 'package:flutter/material.dart';
import 'package:square_dms_trial/models/non_productive_time_model.dart';
import 'package:square_dms_trial/database/non_productive_time_database.dart';
import 'package:intl/intl.dart';

class NonProductiveTimeScreen extends StatefulWidget {
  const NonProductiveTimeScreen({super.key});

  @override
  State<NonProductiveTimeScreen> createState() =>
      _NonProductiveTimeScreenState();
}

class _NonProductiveTimeScreenState extends State<NonProductiveTimeScreen> {
  List<NonProductiveEntry> entries = [];

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  Future<void> loadEntries() async {
    final data = await NonProductiveDB.fetchEntries();
    setState(() => entries = data);
  }

  void showAddEntrySheet() {
    final lineController = TextEditingController();
    final reasonController = TextEditingController();
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final machineNoControler = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: lineController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: "Line No"),
                ),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(labelText: "Reason"),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) startTime = picked;
                      },
                      child: Text("Start Time"),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) endTime = picked;
                      },
                      child: Text("End Time"),
                    ),
                    TextField(
                      controller: machineNoControler,
                      decoration: InputDecoration(
                        labelText: "Number of Machine",
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newEntry = NonProductiveEntry(
                      id: 0,
                      lineNo: int.tryParse(lineController.text) ?? 0,
                      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      startTime: startTime?.format(context) ?? '',
                      endTime: endTime?.format(context) ?? '',
                      machine_num: int.tryParse(machineNoControler.text) ?? 0,
                      reason: reasonController.text,
                    );
                    await NonProductiveDB.insertEntry(newEntry);
                    Navigator.pop(context);
                    loadEntries();
                  },
                  child: Text("Save"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Non-Productive Time")),
      body: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text("Line ${entry.lineNo} - ${entry.reason}"),
              subtitle: Text(
                "${entry.date} | ${entry.startTime} - ${entry.endTime}",
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddEntrySheet,
        child: Icon(Icons.add),
      ),
    );
  }
}
