// import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
import 'package:square_dms_trial/database/capacity_record_database.dart';
import 'package:square_dms_trial/models/capacity_record_model.dart';
import 'package:square_dms_trial/subPages/SkillMatrixOperatorRecordPage.dart';
import 'package:square_dms_trial/globals.dart';

class SkillMatrixRecordPage extends StatefulWidget {
  const SkillMatrixRecordPage({super.key});

  @override
  State<SkillMatrixRecordPage> createState() => _SkillMatrixRecordPageState();
}

class _SkillMatrixRecordPageState extends State<SkillMatrixRecordPage> {
  bool _isSyncing = false;

  List<CapacityRecord> _records = [];

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadRecords(); // Reload when returning to this screen
  }

  Future<void> loadRecords() async {
    final fetchedRecords = await CapacityRecordDatabase.instance.fetchRecords();
    setState(() {
      _records = fetchedRecords;
    });
  }

  Future<void> syncSalesOrdersFromSupabase() async {
    setState(() => _isSyncing = true);
    final client = Supabase.instance.client;

    try {
      // Fetch up to 4000 records
      final List<dynamic> response = await client
          .from('Sales_Order_Data')
          .select()
          .range(0, 5000); // set range based on expected total rows

      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'Sales_Order.db');
      final db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) {
          return db.execute('''
          CREATE TABLE IF NOT EXISTS sales_order_data (
            id INTEGER PRIMARY KEY,
            buyerName TEXT,
            salesDocument INTEGER,
            style TEXT
          )
        ''');
        },
      );

      // Delete old data
      await db.delete('sales_order_data');

      // Insert new data
      final batch = db.batch();
      for (final record in response) {
        batch.insert('sales_order_data', {
          'id': record['Id'],
          'buyerName': record['Buyer_Name'],
          'salesDocument': record['Sales_Document'],
          'style': record['Style'],
        });
      }

      await batch.commit(noResult: true);
      await db.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales Order synced successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sync: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void showAddBottomSheet() async {
    final lineController = TextEditingController();
    final hourlyTargetController = TextEditingController();
    String? selectedBuyer;
    String? selectedSalesDoc;
    String? selectedStyle;
    String? selectedItem;

    List<String> buyers = [];
    List<String> salesDocs = [];
    List<String> styles = [];

    final dbPath = await getDatabasesPath();
    final db = await openDatabase(p.join(dbPath, 'Sales_Order.db'));
    final data = await db.query('sales_order_data');

    buyers =
        data.map((e) => e['buyerName'].toString()).toSet().toList()..sort();

    // print(data);

    // final db = await SalesOrderDatabase.instance.openDatabaseConnection();
    // final allOrders = await SalesOrderDatabase.instance.fetchAllSalesOrders(db);
    // buyers = allOrders.map((e) => e.buyerName).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  top: 46,
                  left: 16,
                  right: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        "Add Capacity Info",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: lineController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Line Number",
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedBuyer,
                        hint: const Text("Select Buyer"),
                        items:
                            buyers.map((buyer) {
                              return DropdownMenuItem(
                                value: buyer,
                                child: Text(buyer),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedBuyer = value;
                            selectedSalesDoc = null;
                            selectedStyle = null;
                            salesDocs =
                                data
                                    .where((row) => row['buyerName'] == value)
                                    .map((e) => e['salesDocument'].toString())
                                    .toSet()
                                    .toList();
                          });
                        },
                      ),
                      if (selectedBuyer != null)
                        DropdownButtonFormField<String>(
                          value: selectedSalesDoc,
                          hint: const Text("Select Sales Document"),
                          items:
                              salesDocs.map((doc) {
                                return DropdownMenuItem(
                                  value: doc,
                                  child: Text(doc),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSalesDoc = value;
                              selectedStyle = null;
                              styles =
                                  data
                                      .where(
                                        (row) =>
                                            row['salesDocument'].toString() ==
                                            value,
                                      )
                                      .map((e) => e['style'].toString())
                                      .toSet()
                                      .toList();
                            });
                          },
                        ),
                      if (selectedSalesDoc != null)
                        DropdownButtonFormField<String>(
                          value: selectedStyle,
                          hint: const Text("Select Style"),
                          items:
                              styles.map((style) {
                                return DropdownMenuItem(
                                  value: style,
                                  child: Text(style),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() => selectedStyle = value);
                          },
                        ),
                      DropdownButtonFormField<String>(
                        value: selectedItem,
                        hint: const Text("Select Item"),
                        items:
                            ['TEE', 'POLO', 'Jacket'].map((item) {
                              return DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                        onChanged:
                            (value) => setState(() => selectedItem = value),
                      ),
                      TextField(
                        controller: hourlyTargetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Hourly Target",
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          if (lineController.text.isEmpty ||
                              selectedBuyer == null ||
                              selectedSalesDoc == null ||
                              selectedStyle == null ||
                              selectedItem == null ||
                              hourlyTargetController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please fill all fields"),
                              ),
                            );
                            return;
                          }

                          final newRecord = CapacityRecord(
                            referenceNumber: 'REF${Random().nextInt(999999)}',
                            lineNumber: int.parse(lineController.text),
                            buyer: selectedBuyer!,
                            salesDocument: selectedSalesDoc!,
                            style: selectedStyle!,
                            item: selectedItem!,
                            layoutTarget: int.parse(
                              hourlyTargetController.text,
                            ),
                            date:
                                DateTime.now()
                                    .toIso8601String()
                                    .split("T")
                                    .first,
                            deptid: userID!,
                          );

                          await CapacityRecordDatabase.instance.insertRecord(
                            newRecord,
                          );

                          if (context.mounted) Navigator.pop(context);
                          loadRecords();
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Skill Matrix Records"),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : syncSalesOrdersFromSupabase,
            icon:
                _isSyncing
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.download),
            tooltip: "Sync Sales Order",
          ),
        ],
      ),
      body:
          _records.isEmpty
              ? const Center(child: Text("No records found."))
              : ListView.builder(
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final record = _records[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text("Line ${record.lineNumber}"),
                      subtitle: Text(
                        "Style: ${record.style} \nDate: ${record.date}",
                      ),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => SkillMatrixOperatorPage(record: record),
                          ),
                        ).then((_) {
                          loadRecords();
                        });
                      },
                    ),
                  );
                },
              ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 94, 43, 255),
        foregroundColor: Colors.white,
        onPressed: showAddBottomSheet,
        child: const Icon(Icons.add),
        tooltip: "Add Capacity Record",
      ),
    );
  }
}
