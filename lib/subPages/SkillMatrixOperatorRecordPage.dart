import 'package:flutter/material.dart';
import '../models/capacity_record_model.dart';
import 'SkillMatrixTimeStudyPage.dart';
import 'package:square_dms_trial/database/sewing_process_database.dart';
import 'package:square_dms_trial/models/sewing_process_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SkillMatrixOperatorPage extends StatefulWidget {
  final CapacityRecord record;
  const SkillMatrixOperatorPage({super.key, required this.record});

  @override
  State<SkillMatrixOperatorPage> createState() =>
      _SkillMatrixOperatorPageState();
}

class _SkillMatrixOperatorPageState extends State<SkillMatrixOperatorPage> {
  bool _isSyncing = false;

  Future<void> syncSewingProcessData() async {
    setState(() => _isSyncing = true);
    try {
      final response =
          await Supabase.instance.client
              .from('sewing_process_database')
              .select();

      final List<SewingProcess> processes =
          response
              .map<SewingProcess>((json) => SewingProcess.fromJson(json))
              .toList();

      await SewingProcessDatabase.instance.deleteDatabaseFile(); // Clear old DB
      await SewingProcessDatabase.instance.database; // Recreate
      await SewingProcessDatabase.instance.insertProcesses(
        processes,
      ); // Insert new data

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
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    )
                    : const Icon(
                      Icons.download,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
            label: const Text(
              "Process",
              style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reference: ${record.referenceNumber}"),
            //   Text("Sales Document: ${record.salesDocument}"),
            // Text("Buyer: ${record.buyer}"),
            //   Text("Style: ${record.style}"),
            //   Text("Item: ${record.item}"),
            //   Text("Layout Target: ${record.layoutTarget}"),
            //   Text("Date: ${record.date}"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 94, 43, 255),
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SkillMatrixTimeStudyPage()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: "Add Process Record",
      ),
    );
  }
}
