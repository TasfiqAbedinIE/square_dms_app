// lib/subPages/non_productive_time_main_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
// import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:square_dms_trial/models/non_productive_time_line_model.dart';
import 'package:square_dms_trial/database/non_productive_time_line_database.dart';
import 'package:square_dms_trial/subPages/NonProductiveTimeReportPage.dart';
import 'package:square_dms_trial/subPages/NonProductiveTimePage.dart';

class NonProductiveTimeMainScreen extends StatefulWidget {
  const NonProductiveTimeMainScreen({Key? key}) : super(key: key);

  @override
  State<NonProductiveTimeMainScreen> createState() =>
      _NonProductiveTimeMainScreenState();
}

class _NonProductiveTimeMainScreenState
    extends State<NonProductiveTimeMainScreen> {
  final _uuid = Uuid();
  DateTime selectedDate = DateTime.now();
  List<NonProductiveTimeLineCard> lineCards = [];

  String? selectedBlock;
  bool isLoading = true;

  List<String> blockOptions = [];
  bool isMasterUser = false;
  // final uuid = Uuid();
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

  @override
  void initState() {
    super.initState();
    _loadLineCards();
    _fetchUserWorkingArea();
  }

  // Fetch user info from supabase
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

  /// Load all line‐cards for the currently selectedDate
  Future<void> _loadLineCards() async {
    final formatted = DateFormat('yyyy-MM-dd').format(selectedDate);
    final cards = await NonProductiveTimeLineDB.fetchCardsByDate(formatted);
    setState(() {
      lineCards = cards;
    });
  }

  /// Download OT factors (unchanged)
  void _downloadOTFactors(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final db = await openDatabase('NonProductive.db');
    try {
      final data = await supabase
          .from('non_productive_time_factors')
          .select('id, idle_factors');

      await db.execute('DROP TABLE IF EXISTS non_productive_factors');
      await db.execute('''
        CREATE TABLE non_productive_factors (
          id INTEGER PRIMARY KEY,
          idle_factors TEXT
        )
      ''');

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

  /// Show modal bottom sheet for creating a new “line card”
  void _showCreateLineCardSheet() async {
    final _lineController = TextEditingController();
    String? selectedBuyer;
    String? selectedSalesDoc;
    String? selectedStyle;
    int? selectedLine;

    List<String> buyers = [];
    List<String> salesDocs = [];
    List<String> styles = [];

    final List<int> userLines =
        blockOptions
            .expand<int>((block) => blockLines[block]?.cast<int>() ?? <int>[])
            .toSet()
            .toList()
          ..sort();

    final dbPath = await getDatabasesPath();
    final db = await openDatabase(path.join(dbPath, 'Sales_Order.db'));
    final data = await db.query('sales_order_data');

    buyers =
        data.map((e) => e['buyerName'].toString()).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext sbc, StateSetter setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sbc).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Line Number input
                    DropdownButtonFormField<int>(
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
                      decoration: const InputDecoration(labelText: "Line No"),
                    ),

                    const SizedBox(height: 12),

                    // Buyer dropdown
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
                    const SizedBox(height: 12),

                    // Sales Order dropdown
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
                    const SizedBox(height: 12),

                    // Style dropdown
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
                    const SizedBox(height: 20),

                    // Create button
                    ElevatedButton(
                      onPressed: () async {
                        // final lineText = _lineController.text.trim();
                        if (selectedLine == null ||
                            selectedBuyer == null ||
                            selectedSalesDoc == null ||
                            selectedStyle == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                            ),
                          );
                          return;
                        }

                        // final lineNo = int.tryParse(lineText);
                        // if (lineNo == null) {
                        //   ScaffoldMessenger.of(context).showSnackBar(
                        //     const SnackBar(
                        //       content: Text('Line number must be numeric'),
                        //     ),
                        //   );
                        //   return;
                        // }

                        final todayStr = DateFormat(
                          'yyyy-MM-dd',
                        ).format(selectedDate);
                        final newId = _uuid.v4();
                        final card = NonProductiveTimeLineCard(
                          id: newId,
                          lineNo: selectedLine!,
                          date: todayStr,
                          buyer: selectedBuyer!,
                          soNumber: selectedSalesDoc!,
                          style: selectedStyle!,
                        );

                        try {
                          await NonProductiveTimeLineDB.insertCard(card);
                          Navigator.pop(context);
                          await _loadLineCards();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Card created successfully'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error creating card: $e')),
                          );
                        }
                      },
                      child: const Text('Create'),
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

  /// Tap a line‐card to navigate into its non‐productive time entry
  void _openNPTimeForCard(NonProductiveTimeLineCard card) {
    // Here you could navigate or show a bottom sheet to record NP time for that line:
    // For example:
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NonProductiveTimeScreen(card: card)),
    );
    // Or reuse an existing method:
    // showAddEntrySheetMB(context, prefillLine: card.lineNo, prefillBuyer: card.buyer, ...);
  }

  void _uploadToCloudForDate(BuildContext context, DateTime date) async {
    final client = Supabase.instance.client;
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final dbPath = await getDatabasesPath();
    final db = await openDatabase(path.join(dbPath, 'NonProductive.db'));

    try {
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

      final uploaded = await client
          .from('non_productive_time')
          .select('id')
          .inFilter('id', localEntries.map((e) => e['id']).toList());

      final uploadedIds = uploaded.map((e) => e['id'].toString()).toSet();

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
        title: const Text("Line Wise Non-Productive Time"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download OT Factor',
            onPressed: () => _downloadOTFactors(context),
          ),
          IconButton(
            icon: const Icon(Icons.upload),
            tooltip: 'Upload OT Data',
            onPressed: () => _uploadToCloudForDate(context, selectedDate),
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
          // Date picker row
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
                        await _loadLineCards();
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
              ],
            ),
          ),

          // “Today’s line cards” list
          Expanded(
            child:
                lineCards.isEmpty
                    ? const Center(child: Text("No line cards for today"))
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: lineCards.length,
                      itemBuilder: (context, index) {
                        final card = lineCards[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            title: Text("Line ${card.lineNo}"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Buyer: ${card.buyer}"),
                                Text(
                                  "SO: ${card.soNumber}   Style: ${card.style}",
                                ),
                              ],
                            ),
                            onTap: () => _openNPTimeForCard(card),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),

      // Floating “+” button to create a new line card
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateLineCardSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}
