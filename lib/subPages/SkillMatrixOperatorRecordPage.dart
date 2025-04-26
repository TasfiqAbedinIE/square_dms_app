import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/capacity_record_model.dart';
import '../models/skill_matrix_record_model.dart';
import '../database/sewing_process_database.dart';
import '../database/capacity_record_database.dart';
import '../models/sewing_process_model.dart';
import 'SkillMatrixTimeStudyPage.dart';

class SkillMatrixOperatorPage extends StatefulWidget {
  final CapacityRecord record;
  const SkillMatrixOperatorPage({super.key, required this.record});

  @override
  State<SkillMatrixOperatorPage> createState() =>
      _SkillMatrixOperatorPageState();
}

class _SkillMatrixOperatorPageState extends State<SkillMatrixOperatorPage> {
  bool _isSyncing = false;
  bool _isUploading = false;
  List<SkillMatrixRecord> _processRecords = [];

  @override
  void initState() {
    super.initState();
    loadProcessRecords();
  }

  Future<void> loadProcessRecords() async {
    final records = await CapacityRecordDatabase.instance
        .fetchSkillMatrixRecords(widget.record.referenceNumber);
    setState(() {
      _processRecords = records;
    });
  }

  Future<void> syncSewingProcessData() async {
    setState(() => _isSyncing = true);
    try {
      final response =
          await Supabase.instance.client
              .from('sewing_process_database')
              .select();

      final processes =
          response
              .map<SewingProcess>((json) => SewingProcess.fromJson(json))
              .toList();

      await SewingProcessDatabase.instance.deleteDatabaseFile();
      await SewingProcessDatabase.instance.database;
      await SewingProcessDatabase.instance.insertProcesses(processes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sewing process data synced successfully."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error syncing process data: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> uploadToSupabase() async {
    setState(() => _isUploading = true);
    final client = Supabase.instance.client;

    try {
      // 1️⃣ Fetch existing records from Supabase for this referenceNumber
      final existingRecords = await client
          .from('skillMatrixRecords')
          .select('referenceNumber, operatorID')
          .eq('referenceNumber', widget.record.referenceNumber);

      final existingOperatorIds =
          existingRecords
              .map<String>((e) => e['operatorID'] as String)
              .toSet(); // Collect existing operator IDs

      int uploadedCount = 0;
      int skippedCount = 0;

      for (var record in _processRecords) {
        if (existingOperatorIds.contains(record.operatorID)) {
          // 2️⃣ Skip if already exists
          skippedCount++;
          continue;
        }
        // 3️⃣ Otherwise, Upload to Supabase
        await client.from('skillMatrixRecords').insert(record.toJson());
        uploadedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Upload complete: $uploadedCount new record(s) uploaded. $skippedCount already existed.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> deleteRecord(SkillMatrixRecord record) async {
    final client = Supabase.instance.client;
    try {
      // Delete from Supabase
      await client.from('skillMatrixRecords').delete().match({
        'referenceNumber': record.referenceNumber,
        'operatorID': record.operatorID,
      });

      // Delete from local SQLite
      final db = await CapacityRecordDatabase.instance.database;
      await db.delete(
        'skillMatrixRecords',
        where: 'referenceNumber = ? AND operatorID = ?',
        whereArgs: [record.referenceNumber, record.operatorID],
      );

      // Reload UI
      loadProcessRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Record deleted successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to delete record: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Process Record"),
        actions: [
          TextButton.icon(
            onPressed: _isSyncing ? null : syncSewingProcessData,
            icon:
                _isSyncing
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                    : const Icon(Icons.download, color: Colors.black),
            label: const Text("Process", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _processRecords.isEmpty
                ? const Center(child: Text("No process records yet."))
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Reference: ${record.referenceNumber}"),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Style: ${record.style}"),
                        Text("Layout Target: ${record.layoutTarget} Pcs"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _processRecords.length,
                        itemBuilder: (context, index) {
                          final r = _processRecords[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text("ID: ${r.operatorID}"),
                              subtitle: Text(
                                "${r.processName} (${r.machine})\nLap: ${r.lapCount}, Avg: ${r.avgCycle}s, Cap/hr: ${r.capacityPH}",
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: const Text("Confirm Deletion"),
                                          content: const Text(
                                            "Are you sure you want to delete this record?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    false,
                                                  ),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    true,
                                                  ),
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        ),
                                  );

                                  if (confirm == true) {
                                    await deleteRecord(r);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : uploadToSupabase,
                      icon:
                          _isUploading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.cloud_upload),
                      label: const Text("Cloud Saved"),
                    ),
                  ],
                ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 94, 43, 255),
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SkillMatrixTimeStudyPage(record: record),
            ),
          );
          loadProcessRecords(); // Refresh when back
        },
        child: const Icon(Icons.add),
        tooltip: "Add Process Record",
      ),
    );
  }
}
